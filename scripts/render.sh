#!/usr/bin/env bash
# Renders every page of examples/render.yaml to PNG by running the SDL build under a virtual
# X display and tapping the real right-hand navigation area.
#   scripts/render.sh [out_dir]          # Linux: needs esphome, Xvfb, xdotool, ImageMagick, SDL2
#   scripts/render.sh --docker [out_dir] # anywhere with Docker (e.g. macOS)
set -euo pipefail
cd "$(dirname "$0")/.."

ESPHOME_VERSION="${ESPHOME_VERSION:-2026.9.1}"

if [[ "${1:-}" == "--docker" ]]; then
  shift
  exec docker run --rm -v "$PWD":/repo -w /repo -e ESPHOME_VERSION \
    --entrypoint bash "ghcr.io/esphome/esphome:${ESPHOME_VERSION}" -c '
      apt-get update -qq && apt-get install -y -qq xvfb xdotool imagemagick libsdl2-dev >/dev/null &&
      scripts/render.sh "$@"' render "$@"
fi

OUT="${1:-renders}"
mkdir -p "$OUT"
LOG="$(mktemp)"
DISPLAY_NUM=":99"

esphome compile examples/render.yaml
BIN="$(find examples/.esphome/build/homedicator-development -name program -type f -perm -u+x | head -1)"

Xvfb "$DISPLAY_NUM" -screen 0 480x480x24 >/dev/null 2>&1 &
XVFB_PID=$!
APP_PID=""
cleanup() { [[ -n "$APP_PID" ]] && kill "$APP_PID" 2>/dev/null; kill "$XVFB_PID" 2>/dev/null; true; }
trap cleanup EXIT
export DISPLAY="$DISPLAY_NUM"
sleep 1

SDL_VIDEODRIVER=x11 "$BIN" >"$LOG" 2>&1 &
APP_PID=$!

for _ in $(seq 60); do grep -q RENDER_READY "$LOG" && break; sleep 0.5; done
grep -q RENDER_READY "$LOG" || { cat "$LOG"; echo "App did not become ready" >&2; exit 1; }
PAGES="$(sed -n 's/.*Pager initialised with \([0-9]*\) pages.*/\1/p' "$LOG" | head -1)"
[[ -n "$PAGES" ]] || { cat "$LOG"; echo "Pager did not initialise" >&2; exit 1; }
sleep 1

# Settings is the last page in the pager cycle; every other page is a user page.
same() { compare -metric AE "$1" "$2" null: >/dev/null 2>&1; }

# LVGL polls the touch state, so hold each tap long enough to be seen.
for i in $(seq 1 "$PAGES"); do
  import -window root -crop 480x480+0+0 "$OUT/page-$i.png"
  if (( i > 1 )) && same "$OUT/page-$((i - 1)).png" "$OUT/page-$i.png"; then
    echo "Tapping next did not change the page (page $i)" >&2; exit 1
  fi
  xdotool mousemove 470 240 mousedown 1 sleep 0.2 mouseup 1   # right_tap_area -> next_page
  sleep 1
done

# After a full cycle we must be back on the first page.
import -window root -crop 480x480+0+0 "$OUT/wraparound.png"
if ! same "$OUT/page-1.png" "$OUT/wraparound.png"; then
  echo "Navigation did not wrap around to the first page" >&2; exit 1
fi
rm "$OUT/wraparound.png"
echo "Rendered $PAGES pages to $OUT/"
