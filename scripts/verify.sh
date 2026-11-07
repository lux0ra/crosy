#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
zip_path="${1:-dist/Crosy-macOS-universal.zip}"
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/crosy-verify.XXXXXX")"
trap 'rm -rf "$check_dir"' EXIT HUP INT TERM
ditto -x -k "$zip_path" "$check_dir"
app="$check_dir/Crosy.app"
exe="$app/Contents/MacOS/Crosy"
plist="$app/Contents/Info.plist"
test -x "$exe"
file "$exe"
lipo "$exe" -verify_arch arm64 x86_64
# Older linked SDKs make AppKit use the legacy control appearance on modern macOS.
otool -arch all -l "$exe" | awk '
  $1 == "sdk" { split($2, version, "."); if (version[1] < 26) exit 1; count++ }
  END { if (count != 2) exit 1 }'

plutil -lint "$plist"
for key in CFBundleName CFBundleDisplayName CFBundleExecutable; do
  test "$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist")" = Crosy
done
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = lol.luxora.crosy
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")" = 13.0
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$plist")" = AppIcon
codesign --verify --strict --all-architectures "$app"
iconutil -c iconset "$app/Contents/Resources/AppIcon.icns" -o "$check_dir/AppIcon.iconset"
for size in 16 32 128 256 512; do
  for suffix in '' '@2x'; do
    png="$check_dir/AppIcon.iconset/icon_${size}x${size}${suffix}.png"
    expected="$size"
    if [ "$suffix" = '@2x' ]; then expected=$((size * 2)); fi
    sips -g pixelWidth -g pixelHeight "$png" | awk -v n="$expected" '
      /pixelWidth:|pixelHeight:/ { if ($2 != n) exit 1; count++ }
      END { if (count != 2) exit 1 }'
  done
done
"$exe" --help
