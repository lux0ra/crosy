#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/icon/AppIcon.iconset
swift -sdk "${SDKROOT:-$(xcrun --show-sdk-path)}" -module-cache-path .build/ModuleCache scripts/render-icon.swift Resources/AppIcon.svg .build/icon/AppIcon-1024.png
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" .build/icon/AppIcon-1024.png --out ".build/icon/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" .build/icon/AppIcon-1024.png --out ".build/icon/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns .build/icon/AppIcon.iconset -o Resources/AppIcon.icns
