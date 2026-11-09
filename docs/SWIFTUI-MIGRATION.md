# SwiftUI editor migration

Prepared for Crosy 26.1.0 and locally checked on 2026-11-09 with Swift 6.3.3 and the macOS 26.5 SDK. The deployment target, bundle identifier, saved JSON schema and preference keys remain unchanged. Both architectures still target macOS 13.

## Scope and architecture

Previously, SettingsController built AppKit controls and directly edited OverlayController's stored Options. The editor is now SwiftUI, embedded through NSHostingController in the existing accessory app. Keeping the NSWindowController and NSApplication lifecycle preserves window reopening, CLI startup, menu actions and quitting behavior without introducing a second SwiftUI app lifecycle.

- SettingsModel is the single MainActor ObservableObject shared by the editor and overlay. It owns Options, transient visibility, language and persistence. It accepts isolated UserDefaults for tests. CLI mode ignores saved options and never writes crosshair settings.
- SwiftUI provides the shape picker, color pickers, center-dot toggle, sliders, exact numeric fields, display selection, language selection and reset confirmation. Standard GroupBox sections keep geometry and placement visible in a compact window. System colors support both appearances. The visibility button uses the standard bordered style on all supported versions; the editor does not apply a custom Liquid Glass style. Visibility animation respects Reduce Motion.
- AppKit retains NSStatusItem, shortcuts, window lifecycle, display notifications and transparent click-through panels at the existing window level. Display identifiers and the disconnected-display choice retain their existing semantics.
- The preview embeds the existing Core Graphics renderer using NSViewRepresentable. It fits oversized crosshairs into its bounds, labels the scale, respects opacity and uses a subtle grid. It does not substitute a second drawing algorithm.
- Combine subscribers pass emitted options/visibility explicitly because Published emits before assigning storage. Language changes refresh the window and menu without rebuilding the overlay. Identical option writes are skipped. Preview drawing is invalidated only when Options change. There are no timers, continuous animations or new dependencies.

Presets were not present and were not added. No performance improvement is claimed. Panel recreation on an actual option change retains the existing implementation.

## Validation

- Direct compilation with `-swift-version 6 -warnings-as-errors`, targeting macOS 13: passed.
- `swift test`: attempted, but the installed swift-package crashes before discovering tests with a missing BuildServerProtocol symbol. XCTest is also unavailable in this Command Line Tools installation. CI retains the normal XCTest suite on macos-26.
- All six methods in Tests/CrosyTests/CrosyTests.swift passed through a temporary direct-compiler runner using assertion helpers instead of XCTest. This fallback is not an XCTest/SwiftPM run. The three added methods cover saved-state reload/reset with language retained, numeric validation/availability, and CLI isolation plus suppression of identical publications. Existing CLI, serialization and legacy migration checks also passed.
- A temporary AppKit GUI runner using production sources and isolated preferences passed: SwiftUI hosting with the shared model, window reopening, exact numeric field commits on focus loss and range clamping, menu shortcut configuration, immediate overlay option updates, visibility from menu and model, all available monitors and offset placement, alpha and click-through, window level/Spaces behavior, disconnected selection, display-change notification, saved JSON readback, and Light/Dark content rendering.
- Light/Dark settings content snapshots were inspected. The editor was subsequently tightened to 680 × 480 points, without a content header or section captions. The standard bordered visibility button sits beside reset in the window footer.
- `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk ./build.sh`: passed for arm64 and x86_64. The signed universal app and distribution ZIP passed the existing extraction, signature, executable, icon and bundle metadata checks. The x86_64 CLI also ran through Rosetta.

The README preview is the user-provided Desktop screenshot from 2026-11-09 at 01.33.16, copied without editing.

The temporary runners and snapshots are under `.build/migration-checks/` and are not distribution resources. They never modify the user's saved crosshair settings.

## Remaining manual checks

Physical Intel hardware, macOS 13–25 runtime behavior, actual monitor unplug/replug, fullscreen games and FPS/CPU/RAM measurements were not tested. There is no global keyboard hook: Cmd-Shift-H remains the existing menu shortcut while Crosy is active. The reset dialog, color panel and all interactions should also receive a normal manual UI pass.

Signing remains ad hoc. Notarization and browser-downloaded Gatekeeper behavior require the existing Developer ID/notarization workflow and were not validated by this migration.
