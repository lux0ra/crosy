#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/release
sdk_path="${SDKROOT:-}"
if [ -z "$sdk_path" ]; then
  tools_sdk="$(xcode-select -p)/SDKs/MacOSX.sdk"
  if [ -d "$tools_sdk" ]; then
    sdk_path="$tools_sdk"
  else
    sdk_path="$(xcrun --show-sdk-path)"
  fi
fi
swiftc -O -parse-as-library \
  -sdk "$sdk_path" \
  -target "$(uname -m)-apple-macosx13.0" \
  Sources/CrosshairOverlay/App.swift \
  Sources/CrosshairOverlay/Options.swift \
  Sources/CrosshairOverlay/Overlay.swift \
  Sources/CrosshairOverlay/Settings.swift \
  Sources/CrosshairOverlay/Localization.swift \
  -o .build/release/CrosshairOverlay
app_path=".build/release/CrosshairOverlay.app"
mkdir -p "$app_path/Contents/MacOS"
cp .build/release/CrosshairOverlay "$app_path/Contents/MacOS/CrosshairOverlay"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
codesign --force --sign - "$app_path"
echo "Готово: $app_path"
