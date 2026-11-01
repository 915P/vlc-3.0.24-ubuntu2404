#!/bin/bash
# Verify compiled VLC 3.0.24 inside container:
#  1. install staging tree into container /usr/local (container-only, no host change)
#  2. run VLC as uid 1000 (VLC refuses root), with host render group for /dev/dri
#  3. prove Intel GPU (VA-API) hardware decoding
set -uo pipefail
RENDER_GID=${RENDER_GID:?RENDER_GID must be provided}
RUNV="setpriv --reuid=1000 --regid=${RENDER_GID} --clear-groups env HOME=/tmp XDG_RUNTIME_DIR=/tmp"

echo "=== install staging -> container /usr/local ==="
cp -a /build/staging/usr/local/. /usr/local/
ldconfig

echo "=== version (as uid 1000) ==="
$RUNV /usr/local/bin/vlc --version | head -3

echo "=== plugin count ==="
$RUNV /usr/local/bin/vlc --list 2>/dev/null | grep -c '^  ' || true

echo "=== VA-API stack (iHD driver) ==="
$RUNV vainfo 2>&1 | grep -E 'VA-API version|Driver version|H264' | head -5

echo "=== make 10s test clip (h264) ==="
ffmpeg -y -v error -f lavfi -i testsrc2=size=1280x720:rate=30 \
       -f lavfi -i sine=frequency=1000 -t 10 \
       -c:v libx264 -preset ultrafast -pix_fmt yuv420p -c:a aac /tmp/test.mp4
ls -l /tmp/test.mp4

echo "=== VLC hardware decode test (VAAPI) ==="
$RUNV /usr/local/bin/vlc -vvv --intf dummy --vout dummy --aout dummy \
    --avcodec-hw=vaapi /tmp/test.mp4 --run-time 4 vlc://quit > /tmp/vlc-vaapi.log 2>&1
echo "--- success line check ('Using ... for hardware decoding') ---"
grep -E 'for hardware decoding' /tmp/vlc-vaapi.log || echo "NO SUCCESS LINE YET"
echo "--- vaapi / hw related lines ---"
grep -iE 'vaapi|hwaccel|hw device|plugin' /tmp/vlc-vaapi.log | head -30
echo "--- errors ---"
grep -iE 'error|failed' /tmp/vlc-vaapi.log | head -20

echo "=== control run: software decode ==="
$RUNV /usr/local/bin/vlc -vvv --intf dummy --vout dummy --aout dummy \
    --avcodec-hw=none /tmp/test.mp4 --run-time 2 vlc://quit > /tmp/vlc-sw.log 2>&1
grep -cE 'for hardware decoding' /tmp/vlc-sw.log || true
echo "=== DONE ==="