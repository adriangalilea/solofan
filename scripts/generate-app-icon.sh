#!/bin/bash
# Generates macOS SoloFanIcon.appiconset PNGs from docs/assets/logo.png
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${ROOT}/docs/assets/logo.png"
ICONSET="${ROOT}/fan/Assets.xcassets/SoloFanIcon.appiconset"
MASTER="${ICONSET}/icon_1024x1024.png"

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing source logo: $SOURCE" >&2
  exit 1
fi

mkdir -p "$ICONSET"

# Pad to square 1024×1024 (centered on transparent canvas via sips padding)
sips -z 1024 1024 "$SOURCE" --out "$MASTER" >/dev/null

generate() {
  local size=$1
  local name=$2
  sips -z "$size" "$size" "$MASTER" --out "${ICONSET}/${name}" >/dev/null
}

generate 16  "icon_16x16.png"
generate 32  "icon_16x16@2x.png"
generate 32  "icon_32x32.png"
generate 64  "icon_32x32@2x.png"
generate 128 "icon_128x128.png"
generate 256 "icon_128x128@2x.png"
generate 256 "icon_256x256.png"
generate 512 "icon_256x256@2x.png"
generate 512 "icon_512x512.png"
generate 1024 "icon_512x512@2x.png"

cat > "${ICONSET}/Contents.json" <<'EOF'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "Generated SoloFanIcon in ${ICONSET}"
