# VLC 3.0.24 build environment — Ubuntu 24.04 (noble)
# Portable version: Ubuntu's default mirrors over plain HTTP (no CA issues).
# The exact variant used for the published deb (USTC IPv6 mirror + Intel graphics PPA)
# is in Dockerfile.ustc-ipv6.
FROM ubuntu:24.04

# enable deb-src so `apt-get build-dep vlc` can resolve build dependencies
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources

# Full VLC build dependencies (same set as Ubuntu's vlc package) + VA-API test tools
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential ca-certificates curl pkg-config gettext autopoint \
      bison flex yasm nasm ccache file \
      libva-dev libvdpau-dev libdrm-dev \
      vainfo intel-media-va-driver-non-free \
      ffmpeg \
    && apt-get build-dep -y vlc \
    && rm -rf /var/lib/apt/lists/*

ENV LC_ALL=C.UTF-8