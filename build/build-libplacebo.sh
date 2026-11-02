#!/usr/bin/env bash
# Build libplacebo 5.264.1 for the v3.0.24-3+ HDR build.
#
# VLC 3.x configure requires `libplacebo >= 0.2.1 libplacebo < 6` (configure.ac),
# but Ubuntu 24.04 ships only libplacebo 6.338.2, so no distro build has tone
# mapping. We build 5.x locally instead. Runs inside the vlc-builder image with
# the workspace mounted at /build (same convention as build.sh); meson and
# ninja are the only packages missing from that image:
#
#   docker run --rm -v "$PWD":/build -w /build vlc-builder bash -c \
#     "apt-get update && apt-get install -y meson ninja-build && \
#      bash /build/build/build-libplacebo.sh"
set -euo pipefail

VER=5.264.1
cd /build

if [ ! -d "libplacebo-$VER" ]; then
  curl -fL -o libplacebo.tar.gz \
    "https://github.com/haasn/libplacebo/archive/refs/tags/v$VER.tar.gz"
  tar xf libplacebo.tar.gz
fi

# The GitHub tag tarball ships no git submodules, so glad is missing and the
# OpenGL backend cannot configure. VLC only uses libplacebo's GPU-agnostic
# shader/color-mapping layer, so opengl/vulkan can both stay disabled.
meson setup pb-build "libplacebo-$VER" \
  --prefix=/build/deps --buildtype=release \
  -Ddemos=false -Dtests=false -Dopengl=disabled -Dvulkan=disabled
ninja -C pb-build
ninja -C pb-build install

# Debian multiarch: the pkg-config file ends up in lib/x86_64-linux-gnu, so the
# VLC configure run needs it on PKG_CONFIG_PATH:
#   export PKG_CONFIG_PATH=/build/deps/lib/x86_64-linux-gnu/pkgconfig
# After `make install DESTDIR=staging`, bundle the runtime library for the deb:
#   cp -a deps/lib/x86_64-linux-gnu/libplacebo.so* staging/usr/local/lib/
#   mkdir -p staging/usr/local/share/doc/libplacebo
#   cp libplacebo-$VER/LICENSE staging/usr/local/share/doc/libplacebo/