# Hardware-acceleration verification (excerpt)

Environment: Ubuntu 24.04 (Linux Mint 22.3), Intel Arrow Lake-P integrated GPU,
Intel iHD VA-API driver 26.3.5, `/dev/dri/renderD128`.

## 1. VA-API stack

```
$ vainfo
libva info: VA-API version 1.24.0
libva info: Trying to open /usr/lib/x86_64-linux-gnu/dri/iHD_drv_video.so
libva info: Found init function __vaDriverInit_1_24
libva info: va_openDriver() returns 0
vainfo: VA-API version: 1.24 (libva 2.23.0)
vainfo: Driver version: Intel iHD driver for Intel(R) Gen Graphics - 26.3.5 ()
vainfo: Supported profile and entrypoints
      VAProfileH264Main               : VAEntrypointVLD
      VAProfileH264High               : VAEntrypointVLD
      VAProfileHEVCMain                : VAEntrypointVLD
      VAProfileHEVCMain10              : VAEntrypointVLD
```

## 2. VLC 3.0.24 with explicit `--avcodec-hw=vaapi` (headless, dummy vout)

```
avcodec decoder debug: available hardware decoder output format 44 (vaapi)
avcodec decoder debug: trying format vaapi
main generic debug: looking for hw decoder module matching "vaapi": 3 candidates
[AVHWDeviceContext] VAAPI driver: Intel iHD driver for Intel(R) Gen Graphics - 26.3.5 ().
main generic debug: using hw decoder module "vaapi_drm"
[h264] Format vaapi chosen by get_format().
[h264] Format vaapi requires hwaccel initialisation.
[h264] Reinit context to 1280x720, pix_fmt: vaapi
avcodec decoder: Using Intel iHD driver for Intel(R) Gen Graphics - 26.3.5 () for hardware decoding
```

## 3. VLC 3.0.24 with default settings (real GUI playback)

```
$ vlc --intf dummy --run-time 6 test.mp4 vlc://quit
[avcodec decoder] Using Intel iHD driver for Intel(R) Gen Graphics - 26.3.5 () for hardware decoding
```

Control run with `--avcodec-hw=none` produces zero occurrences of the line above,
confirming it comes from the hardware decoding path.