# bazzite-lab

Bazzite NVIDIA Open Wayland Lab, using the Universal Blue template.
Final base: `ghcr.io/ublue-os/bazzite-nvidia-open:stable`.
Target: Ryzen 7 5700X3D / RTX 3080, starting from Bazzite Fedora 44.

Stage 2 is under construction in PR #5. Do not deploy this draft until its
build and hardware checks have been completed.

## Sessions

Select a **Wayland Lab** entry in Bazzite's existing display manager.

| Compositor | Shell profiles | Session management |
| --- | --- | --- |
| KineticWE V2 | Native Noctalia KWE fork | Lab supervisor |
| Niri | DMS, Noctalia v5, Waybar minimal | Upstream niri-session |
| Hyprland | DMS, Noctalia v5, Waybar minimal | UWSM |

DMS and Noctalia manage their integrated bar, notifications, polkit and lock.
The minimal profile starts Waybar, Mako and one polkit agent; it uses Swaylock
on demand, without an idle daemon. HyprMod is available in Hyprland.
No third-party rice installer is executed. Waybar provides a small baseline
for comparing the two full shells. Cross-shell KineticWE sessions are not
advertised before testing its custom native integration.

## Configuration

Each combination owns `~/.config/bazzite-lab/<compositor>-<shell>/`.
Defaults are copied on first login; existing edits are retained. Shell configuration,
cache and state are isolated. Applications launched by compositor bindings
retain their normal configuration directories. Noctalia uses its dedicated
configuration variables; DMS requires scoped XDG directories, which applications
launched directly by its shell may inherit. The HyprMod wrapper selects the
current Hyprland profile.

Initial keyboard layout is French. Edit `layout` in `niri/config.kdl` or
`kb_layout` in `hypr/hyprland.lua` to change it. Super+Return opens Foot;
Super+D opens Fuzzel; Super+Q closes a window; Super+Shift+E exits;
Super+Shift+L locks; Super+M opens HyprMod in Hyprland.
KineticWE retains its upstream settings and bindings.

No shell service is globally enabled. Integrated shells do not start alongside
extra notification, polkit or idle daemons. Existing user services/autostarts
are preserved: inspect them if a previous desktop setup already starts these
components. No host configuration is changed by building the image.

Portal routing follows desktop identity: Niri uses GNOME capture and GTK
fallbacks, Hyprland uses its own capture backend and GTK fallbacks, and
KineticWE uses the dedicated KWE backend. Plasma's routing is preserved.

## Build inputs

KineticWE V2 branch `kineticwe-2.0` is pinned to
`219f0d8dc0d57f1337603c31ccedbb0c95351057`, never HEAD. Its compositor,
private KDE libraries, portal and native Noctalia fork are built in Release
in a clean Fedora 44 build stage. A runtime RPM installs them under
`/usr/lib/kineticwe`, without replacing stock KDE or upstream Noctalia files.
The dependency list follows the pinned upstream spec, excluding its greeter.

HyprMod's commit is pinned in `build_files/sources.env`. Its Python dependencies
use upstream lockfile hashes and Fedora PyGObject/Cairo. It installs in
`/usr/libexec/bazzite-lab/hyprmod`, not in a user's home directory.

Niri and Noctalia use Fedora packages. DMS uses the avengemedia/dms and
avengemedia/danklinux COPRs. Hyprland uses nett00n/hyprland for Fedora 44.
External repositories have package allowlists and are disabled after builds.
No Rawhide repository, host rpm-ostree layering or allowerasing is used.

Source pins and RPM inventory are stored in `/usr/share/bazzite-lab/sources.env`
and `rpm-manifest.txt`. The stable base tag and package repositories move;
the complete image is not frozen bit for bit, but the KineticWE revision is.

## Validation

```bash
just check
python3 -m unittest discover -s tests -v
bash -n build_files/build.sh
bash -n build_files/install-runtime.sh
bash -n build_files/build-kineticwe.sh
just build
```

Output: `localhost/bazzite-lab:latest`. The build checks Niri configuration,
required runtime binaries and libraries, pinned KineticWE revision, Python
imports, OCI identity and bootc container lint. Session tests check isolation
and preservation without starting graphical sessions.

Bazzite's inherited chunked layers and OCI configuration are retained. The
legacy rootfs-only rechunker is not used. PR builds do not publish or sign.
Main publication requires SIGNING_SECRET and its matching cosign.pub.
No merge, host rebase or deployment is performed here.

On the RTX 3080, still validate login, rendering, XWayland, monitors/VRR,
audio, clipboard, browser/OBS capture portals, one notification/polkit agent,
locking/unlocking, logout, switching sessions and returning to Plasma.
Verify access to the preceding bootc deployment for rollback.

ISO generation remains deferred. The inherited disk workflow needs the missing
disk_config/iso.toml and project-specific image references before use.
