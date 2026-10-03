#!/bin/bash

set -euo pipefail

source /ctx/sources.env
dnf5 -y copr enable avengemedia/danklinux
dnf5 -y copr enable avengemedia/dms
dnf5 -y copr enable nett00n/hyprland
# Restrict external repos to packages owned by the selected projects.
for file in /etc/yum.repos.d/*avengemedia*danklinux*.repo; do
    sed -i '/^enabled=/a includepkgs=quickshell*,matugen,cliphist,danksearch,dgop,dankcalendar*,material-symbols-fonts' "$file"
done
for file in /etc/yum.repos.d/*avengemedia*dms*.repo; do
    sed -i '/^enabled=/a includepkgs=dms,dms-cli' "$file"
done
for file in /etc/yum.repos.d/*nett00n*hyprland*.repo; do
    sed -i '/^enabled=/a includepkgs=hypr*,aquamarine*,xdg-desktop-portal-hyprland,lua*,glaze*,cpptrace*,libdwarf*,tomlplusplus*' "$file"
done
dnf5 install -y /kineticwe-rpms/*.rpm \
    niri noctalia hyprland uwsm xwayland-satellite \
    xdg-desktop-portal-gnome xdg-desktop-portal-gtk xdg-desktop-portal-hyprland \
    dms quickshell-git matugen cliphist danksearch dgop cava \
    waybar mako fuzzel swaylock wl-clipboard foot \
    python3-gobject python3-cairo gtk4 libadwaita uv git

# Install HyprMod from a pinned checkout and locked, hashed Python dependencies.
# Do not run the upstream installer or write into users' home directories.
git init /tmp/hyprmod
git -C /tmp/hyprmod remote add origin https://github.com/BlueManCZ/hyprmod.git
git -C /tmp/hyprmod fetch --depth=1 origin "$HYPRMOD_COMMIT"
git -C /tmp/hyprmod checkout --detach FETCH_HEAD
test "$(git -C /tmp/hyprmod rev-parse HEAD)" = "$HYPRMOD_COMMIT"
cd /tmp/hyprmod
uv export --frozen --no-dev --no-emit-project --no-emit-package pygobject --no-emit-package pycairo -o /tmp/hyprmod-requirements.txt
uv venv --system-site-packages --python /usr/bin/python3 /usr/libexec/bazzite-lab/hyprmod
uv pip install --python /usr/libexec/bazzite-lab/hyprmod/bin/python --require-hashes -r /tmp/hyprmod-requirements.txt
install -d /usr/libexec/bazzite-lab/hyprmod/src
cp -a hyprmod /usr/libexec/bazzite-lab/hyprmod/src/
glib-compile-schemas /usr/libexec/bazzite-lab/hyprmod/src/hyprmod/data
cp -a data/applications/. /usr/share/applications/
install -d /usr/share/metainfo
cp -a data/metainfo/. /usr/share/metainfo/
cd /
cp -a /ctx/system_files/usr/. /usr/
chmod +x /usr/bin/bazzite-lab-session /usr/bin/bazzite-lab-shell /usr/bin/hyprmod
chmod +x /usr/libexec/bazzite-lab/verify-image

# Publish only the dedicated KWE portal's discovery files. Its resources remain
# private; generic KDE portal discovery stays untouched.
for relative in share/xdg-desktop-portal share/dbus-1/services; do
    install -d "/usr/$relative"
    cp -a "/usr/lib/kineticwe/$relative/." "/usr/$relative/"
done
if [[ -d /usr/lib/kineticwe/lib/systemd/user ]]; then
    cp -a /usr/lib/kineticwe/lib/systemd/user/*kwe* /usr/lib/systemd/user/
fi
# No shell service is globally enabled. The session config starts one shell.
dnf5 -y copr disable avengemedia/danklinux
dnf5 -y copr disable avengemedia/dms
dnf5 -y copr disable nett00n/hyprland
dnf5 clean all
/usr/libexec/bazzite-lab/verify-image
