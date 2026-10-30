#!/usr/bin/env bash
# Builds the browser version of the game into dist/web with love.js.
# Needs Node.js and zip. Serve dist/web with any static file server to try it locally.
set -euo pipefail

# The love.js build of LÖVE 11.5 only lives on GitHub (npm stops at 11.4), so it is pinned to a commit.
LOVEJS="https://github.com/Davidobot/love.js/archive/c4f04e185033a7c9fbefa9be3bec88c41a90421b.tar.gz"

cd "$(dirname "$0")/.."
OUT=dist/web
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

zip -9 -q -r "$TMP/game.love" main.lua lib src resources shaders -x '*.DS_Store'

rm -rf "$OUT"
# Compatibility mode: the default build needs SharedArrayBuffer, which needs COOP/COEP headers that
# GitHub Pages can't send. The cost is that love.thread is unavailable (see src/Core/audio.lua).
npx --yes "$LOVEJS" --title "Table for One" --compatibility "$TMP/game.love" "$OUT"

# Our page replaces the love.js one. Each build gets its own file URLs, so browsers never mix
# files cached from a previous deploy with the new ones.
rm -rf "$OUT/theme"
sed "s/__BUILD__/$(date +%s)/g" web/index.html > "$OUT/index.html"
cp resources/icon.png "$OUT/icon.png"

# love.js only saves to IndexedDB when the page unloads. Expose its file system so the page can
# also save when it is hidden (see web/index.html).
perl -pi -e 's/Module\["FS_createPath"\]=FS\.createPath;/$&Module["FS"]=FS;/' "$OUT/love.js"
if ! grep -q 'Module\["FS"\]=FS;' "$OUT/love.js"; then
    echo "error: could not expose the file system in love.js" >&2
    exit 1
fi

echo "Web build ready in $OUT"
