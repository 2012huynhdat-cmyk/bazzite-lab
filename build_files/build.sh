#!/bin/bash
set -euo pipefail

dnf5 install -y /kineticwe-rpms/*.rpm
cp -a /ctx/system_files/usr/. /usr/
chmod +x /usr/bin/bazzite-lab-session /usr/bin/bazzite-lab-shell /usr/bin/bazzite-lab-lock /usr/bin/hyprmod
chmod +x /usr/libexec/bazzite-lab/verify-image

# Publish only the dedicated KWE portal's discovery files. Its resources remain
# private; generic KDE portal discovery stays untouched.
install -d /usr/share/xdg-desktop-portal /usr/share/dbus-1/services
cp -a /usr/lib/kineticwe/share/xdg-desktop-portal/. /usr/share/xdg-desktop-portal/
cp -a /usr/lib/kineticwe/share/dbus-1/services/org.freedesktop.impl.portal.desktop.kwe.service /usr/share/dbus-1/services/
if [[ -d /usr/lib/kineticwe/lib/systemd/user ]]; then
    cp -a /usr/lib/kineticwe/lib/systemd/user/*kwe* /usr/lib/systemd/user/
fi
# No shell service is globally enabled. The session config starts one shell.
dnf5 clean all
install -m 0644 /ctx/sources.env /usr/share/bazzite-lab/sources.env
rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort > /usr/share/bazzite-lab/rpm-manifest.txt
/usr/libexec/bazzite-lab/verify-image
