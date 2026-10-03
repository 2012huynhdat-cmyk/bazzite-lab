#!/usr/bin/env python3
"""Audit the actual generator output for the pinned, empty Stage 1 profile."""
import json
import pathlib
import sys

context, output = map(pathlib.Path, sys.argv[1:])
containerfile = (context / "Containerfile").read_text()
script = (context / "build_files/build.sh").read_text()
assert "ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-nvidia-open:stable\n" in containerfile
assert "RUN bootc container lint\n" in containerfile
assert "ARG DCLI_BUILD_HASH=dev\n" in containerfile
commands = [line.strip() for line in script.splitlines()
            if line.strip() and not line.lstrip().startswith("#")]
# These are the only reviewed commands allowed in this base-only experiment.
# A changed generator or an added module must trigger a new review.
assert commands == [
    "set -euo pipefail",
    'flatpak remote-add --if-not-exists --system flathub "https://dl.flathub.org/repo/flathub.flatpakrepo"',
    "dnf clean all && rm -rf /var/cache/dnf/*",
], commands
report = {
    "deterministic_generation": True,
    "base_image": "ghcr.io/ublue-os/bazzite-nvidia-open:stable",
    "adds_packages": False,
    "enables_services": False,
    "strict_stage1_noop": False,
    "unexpected_default": "Adds a system Flathub remote despite no Flatpak declarations",
    "cleanup": "Cleans DNF cache even for an empty module",
    "generated_commands": commands,
    "adoption": "Deferred: build compatibility does not imply no-op equivalence or session isolation",
}
(output / "generation-audit.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
