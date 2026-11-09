# Crosy validation

The results below describe the pre-migration AppKit build. For the current SwiftUI editor and its validation, see [SwiftUI migration](SWIFTUI-MIGRATION.md).

Validated on 2026-11-07 on an Apple Silicon Mac running macOS 27.2, with two displays.

- Built both arm64 and x86_64 slices with Swift 6.3.3 and the installed macOS 26.5 SDK, targeting macOS 13.0. `lipo`, `file`, and `otool` confirm both architectures and minimum OS 13.0 in each slice. The current linker records SDK 27.0 in both slices, so the modern AppKit appearance is enabled.
- The x86_64 CLI also ran successfully through Rosetta (`arch -x86_64 .build/release/Crosy --help`); physical Intel hardware remains untested.
- `plutil` and bundle metadata checks passed: Crosy, executable Crosy, bundle ID `lol.luxora.crosy`, minimum macOS 13.0, AppIcon.
- Ad-hoc signature passed `codesign --verify --strict --all-architectures`, including after ZIP extraction. No third-party embedded code or frameworks need separate signing.
- `ditto` created `dist/Crosy-macOS-universal.zip` containing `Crosy.app`. The extracted executable retained execution permission and its CLI help worked.
- ICNS decoded with `iconutil`; all ten 1×/2× representations had their expected dimensions. The 32×32 rendering was visually inspected. Launch Services resolved the custom app icon via `NSWorkspace.icon(forFile:)`; its rendered image was inspected.
- Launched the built app through Launch Services: running name Crosy, bundle ID `lol.luxora.crosy`. It stayed running and was then closed by the launch check.
- A temporary AppKit smoke runner using the production source passed checks for the settings window, three menu actions, branded tooltip, saving settings, rendering, show/hide, placement with offsets on both available displays, unavailable display selection, and responding to a display configuration notification. The runner used its own preferences domain.
- There were no tests in the original repository. Three regression tests were added for CLI validation, settings serialization, and one-time migration with existing values taking priority. All three passed through a temporary direct-compiler runner with assertion helpers.
- `swift test` was attempted but could not start: the installed `swift-package` crashes in dyld with a missing BuildServerProtocol symbol. The temporary runner is a local fallback, not a replacement for the XCTest/SwiftPM suite in CI.
- Shell syntax and `git diff --check` passed.

## Local toolchain limitations

The default `xcrun` macOS 27.0 SDK was built with Swift 6.4, whereas the installed compiler is Swift 6.3.3. An earlier release used SDK 15.4 as a workaround, which unintentionally selected legacy AppKit control styling on modern macOS. That workaround has been removed.

The build now prefers the selected Command Line Tools SDK (macOS 26.5 on this Mac), matching the original build script. It rejects SDKs older than macOS 26, and archive verification checks the SDK recorded in both Mach-O slices. CI uses `macos-26`. The minimum runtime remains macOS 13.0 for both architectures.

```sh
./build.sh
```

The corrected app was installed into `/Applications/Crosy.app` and launched successfully, retaining the existing preferences. Signature verification passed for the installed copy. A native settings-window rendering was inspected; direct system window capture was unavailable in this environment. A build explicitly selecting SDK 15.4 was rejected before compilation, as intended.

No system toolchain files were changed. AppKit UI source and layout remain unchanged from the original app. [Apple documents the SDK-dependent adoption of the new native appearance](https://developer.apple.com/videos/play/wwdc2025/310/).

## Signing and remaining manual checks

No code-signing identities were available. This artifact is ad-hoc signed and is not notarized. Developer ID and notarization remain optional build modes and have not been exercised with real credentials.

`spctl --assess --type execute --verbose=4` returned `accepted` with `override=security disabled`; `spctl --status` reported assessments disabled in the existing environment. These system settings were not changed. This result cannot establish Gatekeeper acceptance on another Mac. No quarantine attributes were removed. See [Apple's first-launch instructions](https://support.apple.com/en-us/102445).

Still requires manual validation: physical Intel hardware, macOS 13 and other older supported releases, a browser-downloaded quarantined archive on a Mac with Gatekeeper enabled, visual appearance inside Finder/Launchpad, and physical display hot-plugging. Display reconfiguration was checked by notification and available-screen placement, not by unplugging the user's monitors.

The GitHub repository was not renamed by this work. Crosy 26.0.0 was subsequently published at the user’s request, replacing the old release.
