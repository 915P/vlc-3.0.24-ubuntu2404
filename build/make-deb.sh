#!/bin/bash
# Package the compiled VLC staging tree as a .deb that replaces Ubuntu's vlc* packages.
set -euo pipefail
S="${VLC_BUILD_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
B=$S/deb
rm -rf "$B"
mkdir -p "$B/DEBIAN"
cp -a "$S/staging/usr" "$B/"

# ---- compute Depends from real shared-library needs of all shipped ELFs ----
tmp=$(mktemp -d)
find "$B/usr/local" -type f \( -name '*.so*' -o -path '*/bin/*' \) -print0 |
while IFS= read -r -d '' f; do ldd "$f" 2>/dev/null || true; done |
  grep '=> /' | awk '{print $3}' | sort -u > "$tmp/libs" || true

# packages we must NOT depend on: our own payload, base system
exclude='^(libc6|libvlc5|libvlccore9|libvlc-bin)$'

: > "$tmp/pkgs"
while read -r lib; do
    real=$(readlink -f "$lib")
    case "$real" in /usr/local/*) continue;; esac
    owner=$(dpkg -S "$real" 2>/dev/null | head -1 | cut -d: -f1 || true)
    if [ -n "$owner" ]; then echo "$owner" >> "$tmp/pkgs"; fi
done < "$tmp/libs"

sort -u "$tmp/pkgs" | grep -Ev "$exclude" | grep -v '^$' | \
  awk 'NR>1{printf ", "} {printf "%s", $0} END{print ""}' > "$tmp/depends"
echo "Depends computed:"
tr ',' '\n' < "$tmp/depends" | sed 's/^ //' | nl

OLDPKGS="libvlc-bin, libvlc5, libvlccore9, vlc-bin, vlc-data, vlc-l10n, \
vlc-plugin-access-extra, vlc-plugin-base, vlc-plugin-notify, vlc-plugin-qt, \
vlc-plugin-samba, vlc-plugin-skins2, vlc-plugin-video-output, \
vlc-plugin-video-splitter, vlc-plugin-visualization"

cat > "$B/DEBIAN/control" <<EOF
Package: vlc
Version: 3.0.24-1
Architecture: amd64
Maintainer: 915P <915P@users.noreply.github.com>
Section: video
Priority: optional
Depends: $(cat "$tmp/depends")
Recommends: intel-media-va-driver-non-free, vainfo
Conflicts: $OLDPKGS
Replaces: $OLDPKGS
Description: VLC media player 3.0.24 (locally compiled, VA-API hw accel enabled)
 Replaces the Ubuntu 3.0.20 vlc package set. Built from the official
 VideoLAN 3.0.24 tarball with --enable-libva --enable-vdpau.
 Installed under /usr/local.
EOF

cat > "$B/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
ldconfig
command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database -q /usr/local/share/applications 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache -f /usr/local/share/icons/hicolor 2>/dev/null || true
exit 0
EOF

cat > "$B/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
ldconfig
exit 0
EOF
chmod 755 "$B/DEBIAN/postinst" "$B/DEBIAN/prerm"

dpkg-deb --build --root-owner-group "$B" "$S/vlc_3.0.24-1_amd64.deb"
dpkg-deb -I "$S/vlc_3.0.24-1_amd64.deb" | sed -n '1,40p'
ls -lh "$S/vlc_3.0.24-1_amd64.deb"
rm -rf "$tmp"