#!/usr/bin/env bash
# The Themes hero next to its reference, in one command:
#
#     ./scripts/review-hero.sh [1400x900 …]        (or: make review)
#
# Builds the debug-tools build, captures the real main window on the Themes
# page at each size, and stacks docs/reference/concept2-reference.png over
# the first capture in build/review/reference-vs-now.png. The captures are
# kept in build/review/now/.
#
#     PAGES=themes,wallpaper,gallery   other pages to capture as well
#     SCROLL=90                        also capture each page scrolled this far
#     REDUCE_MOTION=1, LOW_POWER=1     as with Reduce Motion on, or in Low Power Mode
#     HERO=leopardNoir                 open the carousel on that theme
set -euo pipefail
cd "$(dirname "$0")/.."

SIZES=("$@")
[ ${#SIZES[@]} -eq 0 ] && SIZES=(1400x900)
OUT="build/review"
mkdir -p "$OUT/now"

swift build -c release -Xswiftc -DDEBUG --build-path .build-probe 2>&1 | grep -E "error|warning:|Build complete" || true

joined=$(IFS=,; echo "${SIZES[*]}")
flags=(-renderPages "$PWD/$OUT/now" -pages "${PAGES:-themes}" -pageSizes "$joined" -skip window,wallpaper,widgets,notch)
[ -n "${SCROLL:-}" ] && flags+=(-pageScroll "$SCROLL")
[ -n "${REDUCE_MOTION:-}" ] && flags+=(-reduceMotion 1)
[ -n "${LOW_POWER:-}" ] && flags+=(-lowPower 1)
[ -n "${HERO:-}" ] && flags+=(-heroTheme "$HERO")
.build-probe/release/AllSet "${flags[@]}" >/dev/null

# The hero's part of the reference picture, and the same shape off the top
# of the capture (measured, since a Retina capture has twice the pixels).
first="${SIZES[0]}"
capture="$OUT/now/themes-$first.png"
pixels=$(sips -g pixelWidth "$capture" | awk '/pixelWidth/ { print $2 }')
xcrun swift scripts/stack-images.swift "$OUT/reference-vs-now.png" \
    "Reference (Concept 2)" docs/reference/concept2-reference.png 121,38,634,345 \
    "Now ($first)" "$capture" "0,0,$pixels,$((pixels * 345 / 634))"
echo "$OUT/reference-vs-now.png"
