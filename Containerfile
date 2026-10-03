# Keep build scripts outside the final image (Universal Blue template).
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# A clean build root avoids conflicts between Fedora devel packages and the
# Terra runtime variants inherited by Bazzite. Only the runtime RPM is copied.
FROM registry.fedoraproject.org/fedora:44 AS kineticwe-builder
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build-kineticwe.sh

FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=bind,from=kineticwe-builder,source=/out,target=/kineticwe-rpms \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Validate that the derived image remains bootable with bootc.
RUN bootc container lint
