# CrosshairOverlay

A small macOS app that puts a crosshair in the center of your screen. Pick a shape, adjust it to your liking, and get back to your game. The overlay stays above your apps and lets mouse clicks pass through.

> **holy-vibecoded** (made with AI)

### Features

- **Three shapes** — cross, dot, or circle, with an optional center dot.
- **Live adjustments** — change colors, size, outline, opacity, and position while you watch the preview.
- **Multiple displays** — show the crosshair on your main display, a specific one, or all of them.
- **Menu bar controls** — show or hide the crosshair, open settings, or quit.
- **Russian & English** — switch between **RU / EN** right in the settings window. No restart needed.
- **Saved preferences** — your crosshair settings and language are remembered between launches.

### Build & Run

You'll need **macOS 13+** and **Swift 6+**, available with a compatible Xcode or Command Line Tools installation. There are no third-party dependencies.

If you don't have Command Line Tools yet:

```sh
xcode-select --install
```

Then, from the project folder:

```sh
./build.sh
open .build/release/CrosshairOverlay.app
```

You can copy the built app to **Applications** and launch it from there next time.

### Using the App

Open the app, choose a shape, and adjust the sliders or type exact values into the fields. Changes take effect immediately and save automatically. Settings that don't apply to the current shape are dimmed.

Use **RU / EN** at the bottom of the left column to change the interface language. This translates the settings, tooltips, menu bar controls, and reset dialog. Resetting your crosshair settings keeps your language choice.

Closing the settings window leaves the crosshair running. Click the crosshair icon in the menu bar to bring settings back, hide the overlay, or quit the app. **⌘⇧H** also toggles the crosshair while the app is active.

Sizes are measured in macOS points. Position `0, 0` is the center of the screen; positive offsets move the crosshair right and up.

### Command Line

Prefer the terminal? Launch with arguments to use the overlay without opening settings:

```sh
.build/release/CrosshairOverlay --color 00FF00 --length 12 --gap 5 --center-dot
```

CLI options don't overwrite your saved app settings. Press **Ctrl+C** to stop the process.

See [CLI documentation](docs/CLI.md) for more examples, or run:

```sh
.build/release/CrosshairOverlay --help
```

### Technology Stack

- **Swift 6**
- **AppKit** + **Core Graphics**
- **Swift Package Manager**

<details>
<summary>Project structure & build details</summary>

```text
Sources/CrosshairOverlay/
  App.swift              Entry point and launch mode
  Options.swift          Configuration and CLI parsing
  Overlay.swift          Crosshair rendering and lifecycle
  Settings.swift         Native settings interface
  Localization.swift     Russian and English UI strings
Resources/Info.plist     App bundle metadata
scripts/build.sh         Binary and .app build
build.sh                 Build entry point
Package.swift            Swift package manifest
docs/CLI.md              Terminal usage
.github/workflows/       macOS build checks
```

`./build.sh` produces a standalone binary and a locally signed `.app` in `.build/release/`. Build outputs are ignored by Git.

To use a different SDK:

```sh
SDKROOT=/path/to/MacOSX.sdk ./build.sh
```

To build only the standalone binary with Swift Package Manager:

```sh
swift build -c release
```

</details>

### Notes

No Accessibility or Screen Recording permissions are needed. Some games with exclusive fullscreen rendering may hide the overlay; try a borderless window if that happens.

### License

[MIT](LICENSE)

---

© 2026 luxora.
