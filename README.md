# bazzite-lab

Custom Bazzite OCI image for a future Wayland Lab, based on the
[Universal Blue image template](https://github.com/ublue-os/image-template).
The base is `ghcr.io/ublue-os/bazzite-nvidia-open:stable`.

Stage 1 only establishes the base image and project metadata. It adds no
packages, services, compositors, shells, rices, or user configuration.
The template's tmux installation and podman.socket activation have been removed.
Bazzite's existing packages and services are inherited from the base.

Target hardware: AMD Ryzen 7 5700X3D and NVIDIA RTX 3080.
The starting host runs Bazzite Fedora 44, version 44.20260929.
The requested `stable` base tag moves with upstream releases; it does not
freeze the image to that host version.

## Build and validation

Run from this repository with Git, just and Podman installed:

```bash
just check
bash -n build_files/build.sh
just build
```

The output is `localhost/bazzite-lab:latest`. The Containerfile runs
`bootc container lint` at the end; build success includes that check.
The Justfile supplies the project OCI labels from `image-template.env`.

Pull requests to `main` run the existing container build workflow, including
the template's rpm-ostree rechunking step. Rechunking prepares OCI layers;
it does not layer packages onto the host. PR builds do not publish or sign images.
The existing main-branch workflow publishes to
`ghcr.io/2012huynhdat-cmyk/bazzite-lab:latest` and signs with Cosign.
Before publication, configure the repository's `SIGNING_SECRET` and retain
the matching public key (`cosign.pub`); no public key is present in Stage 1.

The build context and script mounts remain in place for later stages.
The Stage 1 build script intentionally performs no system modifications.
No host rebase, deployment, or rollback operation is performed by these builds.

## Later stages

KineticWE V2, Hyprland, Niri, DMS, Noctalia and HyprMod are future work.
KineticWE must use branch `kineticwe-2.0` at commit
`219f0d8dc0d57f1337603c31ccedbb0c95351057`, with Release or RelWithDebInfo
and a reproducible system installation in the image.
Future changes must isolate shell configurations and configure portals and
session services per compositor while preserving bootc rollback.

ISO generation is deferred. The inherited disk workflow and Justfile currently
reference a missing `disk_config/iso.toml`, and the KDE/GNOME example files
still target the upstream template image. These must be configured and validated
before building an installer. No ISO is built by Stage 1.

A successful OCI build does not validate booting, NVIDIA operation, or rollback
on the target hardware; those require a later deployment test.
