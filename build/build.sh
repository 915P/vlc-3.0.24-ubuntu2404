#!/bin/bash
# Compile VLC 3.0.24 inside container (no root needed; runs as host user)
set -euo pipefail
cd /build/vlc-3.0.24

# Anonymize build provenance embedded in the binary (vlc --version output):
# configure.ac picks up these env vars instead of whoami/hostname.
export VLC_COMPILE_HOST="${VLC_COMPILE_HOST:-build-host}"
export VLC_COMPILE_BY="${VLC_COMPILE_BY:-builder}"

# v3+ HDR tone mapping: if libplacebo 5.x was built into /build/deps (see
# build-libplacebo.sh), link against it and ship its runtime library in the
# staging tree. VLC 3.x requires libplacebo < 6, so this only works from the
# locally built copy, never from the distro package.
CONF_EXTRA=""
DEPS_LIB=""
LIBPLACEBO_PC=$(ls /build/deps/lib/*/pkgconfig/libplacebo.pc 2>/dev/null | head -1 || true)
if [ -n "$LIBPLACEBO_PC" ]; then
    DEPS_LIB=$(dirname "$(dirname "$LIBPLACEBO_PC")")
    export PKG_CONFIG_PATH="$DEPS_LIB/pkgconfig:${PKG_CONFIG_PATH:-}"
    CONF_EXTRA="--enable-libplacebo"

    # Upstream bug (only reachable with libplacebo enabled): the four
    # glconv_* targets in modules/Makefile.in omit $(OPENGL_COMMONCLFAGS),
    # so they fail on converter.h's #include <libplacebo/config.h>.
    # Patch the generated file because the tarball's automake version does
    # not match the distro's, which blocks regenerating Makefile.in.
    if ! grep -q 'OPENGL_COMMONCLFAGS) -DHAVE_VA_X11' modules/Makefile.in; then
        PATCH="$(cd "$(dirname "$0")/.." && pwd)/patches/0001-glconv-libplacebo-cflags.patch"
        echo "=== applying $PATCH ==="
        patch -p1 < "$PATCH"
    fi
fi

echo "=== configure ==="
./configure --prefix=/usr/local --enable-libva --enable-vdpau $CONF_EXTRA \
    > /build/configure.log 2>&1 || {
    echo "CONFIGURE FAILED"; tail -40 /build/configure.log; exit 1; }
echo "configure OK. hw-accel related results:"
grep -iE 'libva|vaapi|vdpau|placebo|avcodec .*: |using avcodec|Qt5|OpenGL' /build/configure.log | tail -30 || true

echo "=== make -j$(nproc) ==="
if ! make -j"$(nproc)" > /build/make.log 2>&1; then
    echo "MAKE FAILED"; grep -nE 'error' /build/make.log | tail -30; exit 1
fi
echo "make OK (errors: $(grep -cE ' error: ' /build/make.log || true))"

echo "=== make install (DESTDIR staging) ==="
make install DESTDIR=/build/staging > /build/install.log 2>&1

if [ -n "$DEPS_LIB" ]; then
    echo "=== bundling libplacebo into staging ==="
    cp -a "$DEPS_LIB"/libplacebo.so* /build/staging/usr/local/lib/
    mkdir -p /build/staging/usr/local/share/doc/libplacebo
    cp /build/libplacebo-5.264.1/LICENSE /build/staging/usr/local/share/doc/libplacebo/
fi

echo "=== done ==="
ls /build/staging/usr/local/bin/
du -sh /build/staging