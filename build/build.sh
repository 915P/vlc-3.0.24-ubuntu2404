#!/bin/bash
# Compile VLC 3.0.24 inside container (no root needed; runs as host user)
set -euo pipefail
cd /build/vlc-3.0.24

# Anonymize build provenance embedded in the binary (vlc --version output):
# configure.ac picks up these env vars instead of whoami/hostname.
export VLC_COMPILE_HOST="${VLC_COMPILE_HOST:-build-host}"
export VLC_COMPILE_BY="${VLC_COMPILE_BY:-builder}"

echo "=== configure ==="
./configure --prefix=/usr/local --enable-libva --enable-vdpau > /build/configure.log 2>&1 || {
    echo "CONFIGURE FAILED"; tail -40 /build/configure.log; exit 1; }
echo "configure OK. hw-accel related results:"
grep -iE 'libva|vaapi|vdpau|avcodec .*: |using avcodec|Qt5|OpenGL' /build/configure.log | tail -30 || true

echo "=== make -j$(nproc) ==="
if ! make -j"$(nproc)" > /build/make.log 2>&1; then
    echo "MAKE FAILED"; grep -nE 'error' /build/make.log | tail -30; exit 1
fi
echo "make OK (errors: $(grep -cE ' error: ' /build/make.log || true))"

echo "=== make install (DESTDIR staging) ==="
make install DESTDIR=/build/staging > /build/install.log 2>&1
echo "=== done ==="
ls /build/staging/usr/local/bin/
du -sh /build/staging