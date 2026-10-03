# dcli-bootc evaluation

This experiment evaluates source revision
`8c3357e5e25d299e4c4570f69a56d8b68dce0ca2` of
[dcli-bootc](https://gitlab.com/theblackdon/dcli-bootc).
It is a selected, inspectable revision, not a claim that it is the latest release.
The source checkout is verified against the full SHA and built in Release mode
with `Cargo.lock` (`--locked`). The CI compiler is pinned to Rust 1.99.0.
Build dependencies still need network access; this is not a vendored/offline build.

The production Containerfile, build script, Justfile and publishing/signing
workflow remain those of Stage 1. This experiment depends on Stage 1 PR #3;
the evaluation PR is separate and must not merge before that dependency.
No compositor, shell, rice or dcli package is added to the production image.

## Run

Prerequisites: Git, Rust/Cargo, Python 3; build mode also needs just and Podman
with working container namespaces and sufficient space for a desktop image and
rechunking. Run from the repository:

```bash
bash tools/evaluate-dcli.sh generate
bash tools/evaluate-dcli.sh build
```

The script fetches the pinned source, compiles the CLI, calls only `gen` in a
temporary project, checks repeatable generation, and audits the generated script.
It does not run upstream installation scripts or invoke dcli init/build/update,
dotfiles, switch, rollback or reboot. Generation uses a temporary XDG config path
and never registers a project in the user's configuration.

Build mode uses a temporary copy of the Universal Blue Justfile for its
OCI labels and build/rechunk recipes. That copy receives `DCLI_BUILD_HASH`, which
the generated Containerfile requires for reliable customization cache invalidation.
The inherited rechunk recipe uses `--rootfs`, which drops the input image's
project labels. The first CI run detected this; the experimental adapter now
passes the existing OCI and Artifact Hub labels explicitly to rechunking.
The production Justfile is untouched; preserving its image configuration
through rechunking needs a separate review before publication.
The generated files are not edited. The image is tagged locally as
`localhost/bazzite-lab-dcli-eval:evaluation`; no registry login, push or signing
occurs. After rechunking, the script checks title/vendor/bootc labels and compares
the RPM package lists of the image and the locally pulled base.

Generated files, the audit and build evidence are saved under the gitignored
`_build_dcli_evaluation/` directory and uploaded as CI artifacts. The existing
production workflow remains responsible for signing/publishing production images.

## Findings from the pinned source

The [generator](https://gitlab.com/theblackdon/dcli-bootc/-/blob/8c3357e5e25d299e4c4570f69a56d8b68dce0ca2/src/generator.rs)
retains the context stage, build mounts and final bootc lint. However:

- An empty profile still emits a system Flathub remote and DNF cleanup. It is
  therefore not a strict no-op equivalent of Stage 1. The audit records this
  difference; CI success must not be read as strict equivalence.
- A module with `files` emits `rsync` of the entire `files/` tree, rather than
  copying only the declared paths. Multiple rice/session modules would need
  additional isolation logic.
- `remote_rpms.sha256` exists in the configuration but is not checked by this
  generator. Download URLs alone do not provide reproducible integrity.
- COPRs are enabled without a corresponding automatic disable operation.
- There are no OCI identity labels in the generated Containerfile; they must
  come from the surrounding build pipeline.

The [CLI](https://gitlab.com/theblackdon/dcli-bootc/-/blob/8c3357e5e25d299e4c4570f69a56d8b68dce0ca2/src/main.rs)
does not expose the `--no-switch` option described in the newer README.
Its [build command](https://gitlab.com/theblackdon/dcli-bootc/-/blob/8c3357e5e25d299e4c4570f69a56d8b68dce0ca2/src/commands/build.rs)
can apply user dotfiles and enter the deployment flow; our experiment avoids it.

## Decision

Do not migrate the production recipe yet. YAML modules are useful, but this
revision needs safeguards for default actions, file selection, integrity checks,
repository cleanup and deployment separation. A newer revision may address
these issues; it must be pinned and evaluated separately rather than following HEAD.
KineticWE's source build and per-session portals/services still need explicit
review regardless of which recipe manager is used.

Image build and bootc lint success cannot validate NVIDIA, booting or rollback
on the target machine. Flatpak configuration in machine-local `/var` is also
not validated by RPM equivalence.

The first build of the raw generated image returned bootc lint exit code zero,
but emitted `var-log` and `var-tmpfiles` warnings for the DNF log and Flatpak
state. The experiment retains those warnings as evidence rather than modifying
the generated script to conceal its defaults.
