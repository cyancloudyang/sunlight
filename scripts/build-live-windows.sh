#!/bin/bash
# Builds Sunlight's live-window pieces into build/live-windows/:
#   payload              the Dock add-on (arm64e, as the Dock is), from LiveWindows/osax/payload.m
#   loader               injects the add-on into the Dock (arm64e, to share the Dock's library addresses)
#   SunlightLiveWindows  the helper the app runs as root; carries both in its __TEXT segment
# scripts/package.sh copies the helper into Sunlight.app/Contents/Helpers.
set -euo pipefail
cd "$(dirname "$0")/.."

# Tablecloth fork: these pieces are the Dock add-on, its loader and the root helper that installs them —
# injection into a system process, which this fork does not build or ship (handoff #11). The sources stay
# as reference; nothing in the app bundle path calls this script any more (scripts/package.sh refuses a
# bundle that carries them). Study only, and only when asked for explicitly.
if [[ "${ALLOW_INJECTOR:-}" != "1" ]]; then
  echo "build-live-windows.sh: the live-windows injector is not built in this fork (see handoff #11)." >&2
  echo "  The snapshot map needs none of it. Set ALLOW_INJECTOR=1 to build it for study only." >&2
  exit 1
fi

OUT=build/live-windows
SRC=LiveWindows
WARN="-Wall -Wextra -Wno-unused-parameter"
mkdir -p "$OUT"

xcrun clang "$SRC/osax/payload.m" $WARN -shared -fPIC -fobjc-arc -O2 -mmacosx-version-min=15.0 -arch arm64e -o "$OUT/payload" \
    -F/System/Library/PrivateFrameworks -framework SkyLight -framework Foundation -framework CoreGraphics
xcrun clang "$SRC/osax/loader.m" -O3 -mmacosx-version-min=15.0 -arch arm64e -o "$OUT/loader" -framework Cocoa
xcrun clang "$SRC/helper.m" $WARN -std=c11 -fobjc-arc -O2 -mmacosx-version-min=15.0 -arch arm64 \
    -o "$OUT/SunlightLiveWindows" -framework Cocoa -framework Security \
    -Wl,-sectcreate,__TEXT,__payload,"$OUT/payload" -Wl,-sectcreate,__TEXT,__loader,"$OUT/loader"
echo "Built $OUT/SunlightLiveWindows"
