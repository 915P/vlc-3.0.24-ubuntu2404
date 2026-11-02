# VLC 3.0.24 for Ubuntu 24.04 (x86_64) — Intel GPU acceleration (VA-API)

Unofficial prebuilt package of **VLC media player 3.0.24** (the latest 3.x release) for
Ubuntu 24.04 Noble / Linux Mint 22.x, compiled from the official VideoLAN source tarball
with **Intel GPU hardware-accelerated decoding (VA-API / VDPAU)** enabled.

> **Disclaimer**: This is an unofficial build. It is not affiliated with, endorsed by,
> or connected to VideoLAN. "VLC" and the VLC cone logo are trademarks of VideoLAN.
> The source code is published by VideoLAN under the GNU GPL — see
> [License](#license) below.

## Release assets

| File | Purpose |
|---|---|
| `vlc_3.0.24-3_amd64.deb` | The built package (installs to `/usr/local`, dpkg-managed) |
| `vlc-3.0.24.tar.xz` | Official VideoLAN source tarball (GPL source for this binary, sha256 verified) |
| `SHA256SUMS` | Checksums for both files |

See [VERIFICATION.md](VERIFICATION.md) for the hardware-decoding test logs.

## Features

- VLC **3.0.24** (2026 release, latest of the 3.x series), `--prefix=/usr/local`
- `./configure --prefix=/usr/local --enable-libva --enable-vdpau`
- **380 plugin modules**, full Qt GUI, 100+ languages
- Built against Ubuntu 24.04 libraries (FFmpeg 6.1, Qt 5.15, libva 2.24)
- Hardware decoding verified on Intel Arrow Lake-P iGPU with the Intel iHD VA-API driver
- Ships as a single dpkg package with a computed `Depends` list (236 ldd-derived runtime libraries + `libc6`)
- **v3.0.24-2 packaging fixes** (after an external review): versioned `Provides` for
  `libvlc5` / `libvlccore9` / `vlc-plugin-base` / `vlc-plugin-video-output` — without them,
  installing *any* third-party package with `Depends: libvlc5` makes apt plan the removal of
  this package; plus `Installed-Size`, an explicit `libc6 (>= 2.38)`, and `Conflicts` extended
  to the whole Ubuntu plugin family (`jack`/`pipewire`/`bittorrent`/`fluidsynth`/`svg`)
- **v3.0.24-3 HDR tone mapping**: built with `--enable-libplacebo` against a locally built
  **libplacebo 5.264.1** (VLC 3.x requires `libplacebo < 6`; Ubuntu 24.04 only ships 6.x, which
  is why no distro build has this), plus one 4-line upstream build fix
  ([`patches/0001-glconv-libplacebo-cflags.patch`](patches/0001-glconv-libplacebo-cflags.patch)).
  The matching runtime library `libplacebo.so.264` is bundled in `/usr/local/lib` (LGPL,
  source pointer in [License](#license)). See [HDR tone mapping](#hdr-tone-mapping-v3024-3).

## Hardware acceleration (verified)

Decoding H.264/HEVC/AV1 etc. on Intel Gen graphics via VA-API. Actual log excerpt
from playing a video with default settings:

```
avcodec decoder debug: available hardware decoder output format 44 (vaapi)
main generic debug: using hw decoder module "vaapi"
[AVHWDeviceContext] VAAPI driver: Intel iHD driver for Intel(R) Gen Graphics - 26.3.5 ().
avcodec decoder: Using Intel iHD driver for Intel(R) Gen Graphics - 26.3.5 () for hardware decoding
```

Requirements: an Intel VA-API driver (`intel-media-va-driver-non-free` for Gen8+,
recommended) and a render node (`/dev/dri/renderD128`). The package `Recommends`
both `intel-media-va-driver-non-free` and `vainfo`.

Check your system with:

```bash
vainfo            # should list your driver + supported profiles
vlc -vvv --intf dummy --vout dummy --avcodec-hw=vaapi some.mp4 --run-time 4 vlc://quit \
  | grep "for hardware decoding"
```

## HDR tone mapping (v3.0.24-3)

VLC 3.x can tone-map HDR (BT.2020/PQ, HDR10) down to an SDR display through libplacebo,
but the feature only exists in builds compiled against **libplacebo 5.x**: the configure
script demands `libplacebo >= 0.2.1 libplacebo < 6`, while Ubuntu 24.04 only ships
`libplacebo 6.338.2`, so distribution builds (including Ubuntu's own VLC) ship without it. This build therefore compiles libplacebo **v5.264.1** from source and links VLC
against it; the runtime `libplacebo.so.264` and its `LICENSE` ship inside the package
under `/usr/local/lib` + `/usr/local/share/doc/libplacebo/`.

Upstream also has a latent build bug that only manifests when libplacebo is enabled:
four GL-converter plugin targets (`glconv_vaapi_wl/x11/drm`, `glconv_vdpau`) omit
`$(OPENGL_COMMONCLFAGS)` (which carries `$(LIBPLACEBO_CFLAGS)`) from their per-target
`CFLAGS`, so they fail to compile on `converter.h`'s `#include <libplacebo/config.h>`.
No distro build enables libplacebo, so nobody ever hit it. The 4-line fix is shipped as
[`patches/0001-glconv-libplacebo-cflags.patch`](patches/0001-glconv-libplacebo-cflags.patch)
(applied to the generated `modules/Makefile.in`).

By default VLC does not tone-map. The `target-prim` and `target-trc` options (display
primaries and transfer function) default to *Unknown*, which makes the color pipeline an
identity transform: PQ frames reach the display unchanged, which is the washed-out HDR
look people complain about. Tell VLC what your display is:

```bash
# SDR display (typical): map BT.2020/PQ → BT.709/sRGB with the default Hable curve
vlc --target-prim=3 --target-trc=2 video.mkv
```

Or make it permanent: add `target-prim=3` and `target-trc=2` to `~/.config/vlc/vlcrc`
(or set them in *Tools → Preferences → Show settings: All → Video*). Related knobs:
`--tone-mapping` (Hable/Mobius/Reinhard/Gamma-Power/Linear/Hard-clip), `--tone-mapping-param`,
`--dither-algo`, `--dither-depth`. On a real HDR display keep the Unknown defaults
(pass-through) instead.

Verified on Intel Arrow Lake-P with a synthetic 720p HDR10 clip (x265, BT.2020/PQ): both
runs decoded through the iHD hardware decoder, and setting the targets changed 497,634
out of 595,200 sampled pixels versus pass-through (mean luminance 0.150 → 0.537). A real
4K HDR10 file then played with hardware decoding and tone mapping active at the same time.

## Install

```bash
sha256sum -c SHA256SUMS
sudo apt install ./vlc_3.0.24-3_amd64.deb
```

**Replacing Ubuntu's packaged VLC?** Ubuntu's `vlc` package set (3.0.20) conflicts with
this build; the package `Conflicts`/`Replaces` the whole set, so the single command above
removes the old player and installs this one. The versioned `Provides` (added in
v3.0.24-2) satisfy anything that `Depends: libvlc5` / `vlc-plugin-base` — including
Ubuntu's `phonon4qt5-backend-vlc` used by `okular` and other KDE apps, which therefore
stays installable without extra steps. (For v3.0.24-1 you had to add
`phonon4qt5-backend-gstreamer` in the same command to avoid apt removing the okular
chain; that is no longer required, though adding it still works if you prefer a
non-VLC phonon backend.) Afterwards `vlc` resolves to
`/usr/local/bin/vlc`, and the desktop menu entry points to it as well.

Uninstall like any normal package:

```bash
sudo apt remove vlc
```

## Building from source

The build is fully containerized — no dev packages on the host, no root needed for
compiling. See [`build/`](build/) for the scripts used (paths parameterized for portability):

1. [`build/Dockerfile`](build/Dockerfile) — Ubuntu 24.04 + full VLC build dependencies
   (`apt-get build-dep vlc` + `libva-dev`/`vainfo`/`ffmpeg`), parameterized mirror
2. [`build/build-libplacebo.sh`](build/build-libplacebo.sh) — v3+: builds libplacebo
   5.264.1 into `/build/deps` (needed because VLC 3.x rejects libplacebo 6.x)
3. [`build/build.sh`](build/build.sh) — `./configure --enable-libva --enable-vdpau && make -j$(nproc)`
   and a `DESTDIR` staging install (build provenance anonymized via
   `VLC_COMPILE_HOST`/`VLC_COMPILE_BY`)
4. [`build/make-deb.sh`](build/make-deb.sh) — packages the staging tree, computes `Depends` from the real
   shared-library requirements of every shipped ELF, adds `Conflicts`/`Replaces` for
   Ubuntu's `vlc*` packages
5. [`build/verify.sh`](build/verify.sh) — installs the staging tree in the container, plays a generated
   H.264 clip through `/dev/dri` and asserts the hardware-decoding log line

The v3 HDR build is automatic: once [`build/build-libplacebo.sh`](build/build-libplacebo.sh)
has populated `/build/deps`, `build.sh` picks it up by itself (adds `PKG_CONFIG_PATH`,
applies the patch above when needed, passes `--enable-libplacebo`) and bundles
`libplacebo.so.264` plus its license into the staging tree.

```bash
docker build -t vlc-builder build/
tar xf vlc-3.0.24.tar.xz          # source tree next to build/
docker run --rm -v "$PWD":/build -w /build vlc-builder bash /build/build/build.sh
bash build/make-deb.sh            # -> vlc_3.0.24-3_amd64.deb
```

Path conventions: `build.sh` / `verify.sh` run *inside* the container where the build
directory is mounted at `/build` (the source tree must be extracted as `/build/vlc-3.0.24`);
`make-deb.sh` runs on the host and reads `S=` at the top of the script (defaults to the
repository/build directory).

Notes from our own build environment (kept for reproducibility):

- `build/Dockerfile.ustc-ipv6` — the exact Dockerfile used for this release: it pulls
  packages from the **USTC IPv6 mirror** (`https://ipv6.mirrors.ustc.edu.cn/ubuntu`)
  and the **kobuk Intel graphics PPA** (libva 2.24 + iHD driver 26.3.5, not mirrored
  by USTC). The base image lacks `ca-certificates`, so the host CA bundle is copied in
  for the HTTPS mirror.
- The source tarball was fetched from the USTC `videolan-ftp` mirror and checked
  against the official sha256 published by VideoLAN.

## License

VLC is distributed under the terms of the **GNU General Public License, version 2**
(some parts LGPLv2.1).

- Corresponding source: `vlc-3.0.24.tar.xz` attached to this release — the exact,
  unmodified upstream tarball (sha256: `e7cab503d1d7d5849b89d2cf0e1ee60d0ef6d012407791b644b9cfc0cc225fdf`,
  as published by VideoLAN at `https://download.videolan.org/pub/videolan/vlc/3.0.24/`).
- From v3.0.24-3 the build applies one 4-line patch to the generated
  `modules/Makefile.in` (see the [HDR tone mapping](#hdr-tone-mapping-v3024-3) section).
  The exact patch ships in this repository as
  [`patches/0001-glconv-libplacebo-cflags.patch`](patches/0001-glconv-libplacebo-cflags.patch);
  the tarball plus that patch is the full build input.
- The package also bundles **libplacebo 5.264.1** (LGPL-2.1-or-later) as
  `/usr/local/lib/libplacebo.so.264`, with its license text installed at
  `/usr/local/share/doc/libplacebo/LICENSE`. Source:
  <https://github.com/haasn/libplacebo>, tag `v5.264.1` (the fetched tarball we used has
  sha256 `1e8be260e104c0be061305e3c0f2099c79776528889d426c497da153e85f8b5c`).
- Build scripts in this repository are provided under GPLv2 as well.