import AppKit

@MainActor
final class CrosshairView: NSView {
    let options: Options

    init(options: Options) {
        self.options = options
        super.init(frame: NSRect(x: 0, y: 0, width: options.canvasSize, height: options.canvasSize))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        let o = options
        let x = bounds.midX
        let y = bounds.midY
        let shape = CGMutablePath()
        if o.style == "cross" {
            shape.addRect(CGRect(x: x - o.thickness / 2, y: y + o.gap,
                                 width: o.thickness, height: o.length))
            shape.addRect(CGRect(x: x - o.thickness / 2, y: y - o.gap - o.length,
                                 width: o.thickness, height: o.length))
            shape.addRect(CGRect(x: x + o.gap, y: y - o.thickness / 2,
                                 width: o.length, height: o.thickness))
            shape.addRect(CGRect(x: x - o.gap - o.length, y: y - o.thickness / 2,
                                 width: o.length, height: o.thickness))
        } else if o.style == "circle" {
            let circle = CGPath(ellipseIn: CGRect(x: x - o.radius, y: y - o.radius,
                                                  width: 2 * o.radius, height: 2 * o.radius), transform: nil)
            shape.addPath(circle.copy(strokingWithWidth: o.thickness, lineCap: .butt,
                                      lineJoin: .round, miterLimit: 10))
        }
        if o.style == "dot" || o.centerDot {
            shape.addEllipse(in: CGRect(x: x - o.dotSize / 2, y: y - o.dotSize / 2,
                                        width: o.dotSize, height: o.dotSize))
        }
        // Outline first, then fill the entire shape to preserve the requested line thickness.
        if o.outline > 0 {
            context.addPath(shape)
            context.setStrokeColor(NSColor(rgbHex: o.outlineColor).cgColor)
            context.setLineWidth(o.outline * 2)
            context.setLineJoin(.round)
            context.strokePath()
        }
        context.addPath(shape)
        context.setFillColor(NSColor(rgbHex: o.color).cgColor)
        context.fillPath()
    }
}

@MainActor
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayController: NSObject, NSApplicationDelegate {
    private(set) var options: Options
    private var settings: SettingsController?
    private var statusItem: NSStatusItem?
    private var visibilityMenuItem: NSMenuItem?
    private let usesSettings: Bool
    private(set) var isEnabled = true
    private var panels: [OverlayPanel] = []
    private var signalSources: [DispatchSourceSignal] = []

    init(options: Options, usesSettings: Bool) {
        self.usesSettings = usesSettings
        if usesSettings,
           let data = UserDefaults.standard.data(forKey: "crosshair.settings"),
           let saved = try? JSONDecoder().decode(Options.self, from: data) {
            self.options = saved
        } else {
            self.options = options
        }
    }

    func update(_ options: Options) {
        self.options = options
        if usesSettings, let data = try? JSONEncoder().encode(options) {
            UserDefaults.standard.set(data, forKey: "crosshair.settings")
        }
        rebuild()
    }

    @objc func toggleEnabled() {
        isEnabled.toggle()
        rebuild()
        settings?.refreshEnabled()
        refreshMenu()
    }

    private func refreshMenu() {
        visibilityMenuItem?.title = L.text(isEnabled ? "Скрыть прицел" : "Показать прицел")
        visibilityMenuItem?.state = isEnabled ? .on : .off
        statusItem?.button?.toolTip = L.text(isEnabled ? "CrosshairOverlay — прицел включён" : "CrosshairOverlay — прицел выключен")
    }

    func refreshLanguage() {
        for entry in statusItem?.menu?.items ?? [] {
            if entry.action == #selector(showSettings) { entry.title = L.text("Настройки прицела…") }
            if entry.action == #selector(quit) { entry.title = L.text("Завершить") }
        }
        refreshMenu()
    }

    @objc func showSettings() {
        settings?.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        settings?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }


    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(self, selector: #selector(rebuild),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        for number in [SIGINT, SIGTERM] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { NSApplication.shared.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
        if usesSettings {
            settings = SettingsController(overlay: self)
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = NSImage(systemSymbolName: "scope", accessibilityDescription: "CrosshairOverlay")
            let menu = NSMenu()
            for (title, action, key) in [
                ("Настройки прицела…", #selector(showSettings), ","),
                ("Скрыть прицел", #selector(toggleEnabled), "h"),
                ("Завершить", #selector(quit), "q")
            ] {
                let entry = menu.addItem(withTitle: L.text(title), action: action, keyEquivalent: key)
                entry.target = self
                if action == #selector(toggleEnabled) {
                    entry.keyEquivalentModifierMask = [.command, .shift]
                    visibilityMenuItem = entry
                }
            }
            item.menu = menu
            statusItem = item
            refreshMenu()
            showSettings()
        }
        rebuild()
        print("Прицел запущен (PID \(ProcessInfo.processInfo.processIdentifier)). Остановка: Ctrl+C.")
    }

    @objc private func rebuild() {
        for panel in panels { panel.orderOut(nil); panel.close() }
        panels.removeAll()
        guard isEnabled else { return }
        let screens: [NSScreen]
        if options.screen == "all" {
            screens = NSScreen.screens
        } else if let index = Int(options.screen) {
            screens = NSScreen.screens.indices.contains(index) ? [NSScreen.screens[index]] : []
        } else {
            // The first screen owns the menu bar; NSScreen.main follows keyboard focus.
            screens = Array(NSScreen.screens.prefix(1))
        }
        for screen in screens {
            let size = options.canvasSize
            let frame = NSRect(x: screen.frame.midX - size / 2 + options.offsetX,
                               y: screen.frame.midY - size / 2 + options.offsetY,
                               width: size, height: size)
            let panel = OverlayPanel(contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.isFloatingPanel = true
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            if #available(macOS 13.0, *) {
                panel.collectionBehavior.insert(.canJoinAllApplications)
            }
            panel.alphaValue = options.opacity
            panel.contentView = CrosshairView(options: options)
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }
}
