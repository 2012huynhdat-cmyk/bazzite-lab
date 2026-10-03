#!/bin/bash
set -euo pipefail
source /ctx/sources.env
export CMAKE_BUILD_PARALLEL_LEVEL=2
prefix=/usr/lib/kineticwe
mkdir -p /tmp/kwe /out /tmp/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cd /tmp/kwe
dnf5 install -y git rpm-build
fetch() {
    git init "$1"
    git -C "$1" remote add origin "$2"
    git -C "$1" fetch --depth=1 origin "$3"
    git -C "$1" checkout --detach FETCH_HEAD
    test "$(git -C "$1" rev-parse HEAD)" = "$3"
}
fetch source https://gitlab.com/theblackdon/kineticwe.git "$KINETICWE_COMMIT"
fetch kglobalacceld https://invent.kde.org/plasma/kglobalacceld.git "$KGLOBALACCELD_COMMIT"
fetch kdecoration https://invent.kde.org/plasma/kdecoration.git "$KDECORATION_COMMIT"
mapfile -t deps < /ctx/kineticwe-build-deps.txt
dnf5 install -y rpm-build git "${deps[@]}"
# Keep all fork resources and libraries under a private prefix. No stock KDE
# files, Noctalia resources, login manager, or host configuration are replaced.
cmake -S kglobalacceld -B kglobalacceld-build -GNinja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib64 -DCMAKE_INSTALL_RPATH="$prefix/lib64"
cmake --build kglobalacceld-build
cmake --install kglobalacceld-build
cmake -S kdecoration -B kdecoration-build -GNinja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib64 -DCMAKE_INSTALL_RPATH="$prefix/lib64"
cmake --build kdecoration-build
cmake --install kdecoration-build
cmake -S source -B compositor-build -GNinja \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib64 \
    -DCMAKE_PREFIX_PATH="$prefix" -DCMAKE_INSTALL_RPATH="$prefix/lib64" \
    -DKWIN_BUILD_KCMS=OFF -DCMAKE_DISABLE_FIND_PACKAGE_KF6DocTools=ON
cmake --build compositor-build
cmake --install compositor-build
cmake -S source/portal/xdg-desktop-portal-kwe -B portal-build -GNinja \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
    -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib64 \
    -DCMAKE_INSTALL_RPATH="$prefix/lib64"
cmake --build portal-build
cmake --install portal-build
meson setup shell-build source/shell/noctalia --prefix "$prefix" --libdir lib64 --buildtype release -Dtests=disabled -Dnative_optimizations=false
meson compile -C shell-build -j 2
meson install -C shell-build
mkdir -p /tmp/kwe-stage/usr/lib
cp -a "$prefix" /tmp/kwe-stage/usr/lib/
rm -rf /tmp/kwe-stage/usr/lib/kineticwe/include /tmp/kwe-stage/usr/lib/kineticwe/lib64/cmake
printf '%s\n' "$KINETICWE_COMMIT" > /tmp/kwe-stage/usr/lib/kineticwe/SOURCE_COMMIT
cat > /tmp/rpmbuild/SPECS/kineticwe-lab.spec <<'SPEC'
%global __provides_exclude_from ^/usr/lib/kineticwe/.*$
%global __requires_exclude ^lib(KGlobalAccelD|kdecorations3|kineticwe).*$
%global debug_package %{nil}
%global __brp_check_rpaths %{nil}
Name: kineticwe-lab
Version: 2.0
Release: 1
Summary: Pinned KineticWE Wayland Lab runtime in a private prefix
License: GPL-2.0-or-later AND LGPL-2.0-or-later AND MIT AND BSD-3-Clause AND CC0-1.0
URL: https://gitlab.com/theblackdon/kineticwe
%description
Compositor, private KDE libraries, portal and Noctalia fork for bazzite-lab.
%install
mkdir -p %{buildroot}
cp -a /tmp/kwe-stage/. %{buildroot}/
%files
/usr/lib/kineticwe
SPEC
rpmbuild -bb --define '_topdir /tmp/rpmbuild' /tmp/rpmbuild/SPECS/kineticwe-lab.spec
cp /tmp/rpmbuild/RPMS/*/*.rpm /out/
