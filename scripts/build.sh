#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sdk_path="${SDKROOT:-}"
if [ -z "$sdk_path" ]; then
  tools_sdk="$(xcode-select -p)/SDKs/MacOSX.sdk"
  if [ -d "$tools_sdk" ]; then
    sdk_path="$tools_sdk"
  else
    sdk_path="$(xcrun --show-sdk-path)"
  fi
fi
# AppKit chooses its native control appearance from the SDK linked at build time.
sdk_version="$(/usr/libexec/PlistBuddy -c 'Print :Version' "$sdk_path/SDKSettings.plist")"
if [ "${sdk_version%%.*}" -lt 26 ]; then
  echo "Use a matching Swift toolchain and macOS 26+ SDK to preserve Crosy's native appearance (selected: $sdk_version)." >&2
  exit 1
fi
echo "Building Crosy with macOS SDK $sdk_version"
identity="${CODESIGN_IDENTITY:--}"
if [ -n "${NOTARY_PROFILE:-}" ] && [ "$identity" = - ]; then
  echo 'NOTARY_PROFILE requires a Developer ID Application CODESIGN_IDENTITY.' >&2
  exit 1
fi
mkdir -p .build/release dist
for arch in arm64 x86_64; do
  xcrun swiftc -O -parse-as-library -module-cache-path .build/ModuleCache -sdk "$sdk_path" \
    -target "$arch-apple-macosx13.0" \
    Sources/CrosshairOverlay/*.swift -o ".build/release/Crosy-$arch"
done
lipo -create .build/release/Crosy-arm64 .build/release/Crosy-x86_64 -output .build/release/Crosy
lipo .build/release/Crosy -verify_arch arm64 x86_64
app_path=".build/release/Crosy.app"
# Recreate only this generated bundle so stale resources never enter a signature.
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp .build/release/Crosy "$app_path/Contents/MacOS/Crosy"
chmod 755 "$app_path/Contents/MacOS/Crosy"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
cp Resources/AppIcon.icns "$app_path/Contents/Resources/AppIcon.icns"
plutil -lint "$app_path/Contents/Info.plist"
if [ "$identity" = - ]; then
  codesign --force --sign - "$app_path"
else
  codesign --force --options runtime --timestamp --sign "$identity" "$app_path"
fi
codesign --verify --strict --all-architectures "$app_path"
# Keep the standalone CLI identical to the signed bundle executable.
cp "$app_path/Contents/MacOS/Crosy" .build/release/Crosy
zip_path="dist/Crosy-macOS-universal.zip"
rm -f "$zip_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
if [ -n "${NOTARY_PROFILE:-}" ]; then
  xcrun notarytool submit "$zip_path" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$app_path"
  xcrun stapler validate "$app_path"
  rm -f "$zip_path"
  ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
fi
./scripts/verify.sh "$zip_path"
echo "Готово: $app_path; $zip_path"
