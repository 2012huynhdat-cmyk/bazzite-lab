#!/usr/bin/env bash
set -euo pipefail

mode=${1:-generate}
if [[ "$mode" != generate && "$mode" != build ]]; then
    echo "Usage: bash tools/evaluate-dcli.sh [generate|build]" >&2
    exit 2
fi
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
experiment="$repo_dir/experiments/dcli-bootc"
# shellcheck source=../experiments/dcli-bootc/upstream.env
source "$experiment/upstream.env"
[[ "$DCLI_REVISION" =~ ^[0-9a-f]{40}$ ]]
work_dir=$(mktemp -d "${TMPDIR:-/tmp}/bazzite-lab-dcli.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT
context="$work_dir/context"
output="$repo_dir/_build_dcli_evaluation"
mkdir -p "$context" "$output"

# Fetch only the reviewed source revision. No COPR or installer scripts.
git init -q "$work_dir/source"
git -C "$work_dir/source" remote add origin "$DCLI_REPOSITORY"
git -C "$work_dir/source" fetch --depth=1 origin "$DCLI_REVISION"
git -C "$work_dir/source" checkout -q --detach FETCH_HEAD
test "$(git -C "$work_dir/source" rev-parse HEAD)" = "$DCLI_REVISION"
rustc --version
cargo --version
cargo build --locked --release --manifest-path "$work_dir/source/Cargo.toml"
binary="$work_dir/source/target/release/dcli-bootc"

cp "$experiment/profile.yaml" "$context/profile.yaml"
cp -a "$experiment/modules" "$experiment/files" "$context/"
touch "$context/.dcli-bootc"
# gen writes only to this temporary project. Do not use build/update/switch.
XDG_CONFIG_HOME="$work_dir/config" "$binary" --project "$context" gen
cp "$context/Containerfile" "$output/Containerfile"
cp "$context/build_files/build.sh" "$output/build.sh"
XDG_CONFIG_HOME="$work_dir/config" "$binary" --project "$context" gen
cmp "$context/Containerfile" "$output/Containerfile"
cmp "$context/build_files/build.sh" "$output/build.sh"
bash -n "$context/build_files/build.sh"
python3 "$repo_dir/tools/audit-dcli.py" "$context" "$output"

if [[ "$mode" == generate ]]; then
    echo "Generation audit saved to $output; no image or deployment changed."
    exit 0
fi

# Use the template's labels and build recipe in a disposable context.
# Inject the required cache key into this COPY of the Justfile only.
cp "$repo_dir/Justfile" "$repo_dir/image-template.env" "$context/"
python3 - "$context" <<'PY'
import hashlib
import pathlib
import sys
context = pathlib.Path(sys.argv[1])
digest = hashlib.sha256()
for directory in ("build_files", "files"):
    for path in sorted((context / directory).rglob("*")):
        if path.is_file():
            digest.update(str(path.relative_to(context)).encode() + b"\0")
            digest.update(path.read_bytes())
justfile = context / "Justfile"
text = justfile.read_text()
assert text.count("    BUILD_ARGS=()") == 1
justfile.write_text(text.replace(
    "    BUILD_ARGS=()",
    '    BUILD_ARGS=("--build-arg" "DCLI_BUILD_HASH=' + digest.hexdigest() + '")',
))
PY
# Record source/revision labels from our repository rather than a temporary git repo.
export GIT_DIR="$repo_dir/.git"
export GIT_WORK_TREE="$repo_dir"
(
    cd "$context"
    just build bazzite-lab-dcli-eval evaluation
    just ostree-rechunk bazzite-lab-dcli-eval evaluation
)
podman image inspect localhost/bazzite-lab-dcli-eval:evaluation > "$output/image-inspect.json"

# Verify the declared identity and inherited bootc capability after rechunking.
python3 - "$output/image-inspect.json" <<'PY'
import json
import sys
labels = json.load(open(sys.argv[1]))[0]["Labels"]
assert labels["org.opencontainers.image.title"] == "bazzite-lab"
assert labels["org.opencontainers.image.vendor"] == "2012huynhdat-cmyk"
assert labels["containers.bootc"] == "1"
PY

# Check package equivalence against the exact base image used by this build.
# No user home is mounted and containers have no network access.
for image in ghcr.io/ublue-os/bazzite-nvidia-open:stable localhost/bazzite-lab-dcli-eval:evaluation; do
    filename=base-packages.txt
    [[ "$image" == localhost/* ]] && filename=image-packages.txt
    podman run --rm --network=none --entrypoint rpm "$image" \
        -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | LC_ALL=C sort > "$output/$filename"
done
diff -u "$output/base-packages.txt" "$output/image-packages.txt"
echo "OCI build, bootc lint, rechunking, metadata and RPM equivalence passed."
