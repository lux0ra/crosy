import AppKit

@MainActor
private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class SettingsController: NSWindowController, NSTextFieldDelegate, NSWindowDelegate {
    private unowned let overlay: OverlayController
    private let content = NSStackView()
    private let appearance = NSStackView()
    private let adjustments = NSStackView()
    private let enabled = NSButton(checkboxWithTitle: "Показывать прицел", target: nil, action: nil)
    private let preview = NSView()
    private let style = NSSegmentedControl(labels: ["Крест", "Точка", "Кольцо"], trackingMode: .selectOne, target: nil, action: nil)
    private let screen = NSPopUpButton()
    private let language = NSSegmentedControl(labels: ["RU", "EN"], trackingMode: .selectOne, target: nil, action: nil)
    private var languageUpdates: [() -> Void] = []
    private var sliders: [String: NSSlider] = [:]
    private var values: [String: NSTextField] = [:]
    private var colors: [NSColorWell] = []
    private var rowLabels: [String: NSTextField] = [:]
    private var limits: [String: ClosedRange<Double>] = [:]
    private let previewCaption = NSTextField(labelWithString: "Предпросмотр · 1:1")
    private let centerDot = NSButton(checkboxWithTitle: "Точка в центре", target: nil, action: nil)

    init(overlay: OverlayController) {
        self.overlay = overlay
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 584, height: 460),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = L.text("Настройки прицела")
        window.isReleasedWhenClosed = false
        window.autorecalculatesKeyViewLoop = true
        super.init(window: window)
        window.delegate = self
        build()
        window.center()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshScreens),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    private func build() {
        guard let root = window?.contentView else { return }
        let scroll = NSScrollView(frame: root.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        root.addSubview(scroll)
        let document = SettingsDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        content.orientation = .horizontal
        content.alignment = .top
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: document.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -16)
        ])
        for column in [appearance, adjustments] {
            column.orientation = .vertical
            column.alignment = .leading
            column.spacing = 8
            content.addArrangedSubview(column)
        }
        appearance.widthAnchor.constraint(equalToConstant: 196).isActive = true
        adjustments.widthAnchor.constraint(equalToConstant: 340).isActive = true
        let title = NSTextField(labelWithString: "Ваш прицел")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        appearance.addArrangedSubview(title)
        enabled.target = self
        enabled.action = #selector(toggle)
        appearance.addArrangedSubview(enabled)
        enabled.toolTip = "Скрыть или показать прицел, сохранив все настройки."
        enabled.setAccessibilityLabel("Видимость прицела")
        refreshEnabled()

        preview.wantsLayer = true
        preview.layer?.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 1).cgColor
        preview.layer?.cornerRadius = 10
        preview.layer?.masksToBounds = true
        appearance.addArrangedSubview(preview)
        preview.widthAnchor.constraint(equalTo: appearance.widthAnchor).isActive = true
        preview.heightAnchor.constraint(equalToConstant: 112).isActive = true

        previewCaption.font = .systemFont(ofSize: 11)
        previewCaption.textColor = .secondaryLabelColor
        appearance.addArrangedSubview(previewCaption)

        style.setAccessibilityLabel("Форма прицела")
        style.toolTip = "Выберите форму. Доступные настройки справа зависят от неё."
        style.target = self
        style.action = #selector(changeStyle)
        appearance.addArrangedSubview(style)
        style.widthAnchor.constraint(equalTo: appearance.widthAnchor).isActive = true
        for (index, title) in ["Цвет прицела", "Цвет обводки"].enumerated() {
            let well = NSColorWell()
            well.tag = index
            well.target = self
            well.action = #selector(changeColor(_:))
            colors.append(well)
            row(title, control: well, column: appearance)
        }
        centerDot.target = self
        centerDot.action = #selector(changeDot)
        appearance.addArrangedSubview(centerDot)
        let reset = NSButton(title: "Сбросить настройки", target: self, action: #selector(reset))
        appearance.addArrangedSubview(reset)
        let hint = NSTextField(wrappingLabelWithString: "Настройки сохраняются автоматически.")
        hint.toolTip = "Закрытие окна оставляет прицел работать. Открыть настройки можно в строке меню."
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        appearance.addArrangedSubview(hint)
        hint.widthAnchor.constraint(equalTo: appearance.widthAnchor).isActive = true

        language.target = self
        language.action = #selector(changeLanguage)
        language.setAccessibilityLabel("Language / Язык")
        row("Язык", control: language, column: appearance)

        let heading = NSTextField(labelWithString: "Геометрия прицела")
        heading.font = .systemFont(ofSize: 14, weight: .semibold)
        adjustments.addArrangedSubview(heading)
        addSlider("length", "Длина лучей", 0...1000, visible: 0...40)
        addSlider("gap", "Отступ от центра", 0...1000, visible: 0...30)
        addSlider("thickness", "Толщина", 0.25...1000, visible: 0.25...10)
        addSlider("radius", "Радиус кольца", 0.25...1000, visible: 0.25...40)
        addSlider("dotSize", "Размер точки", 0.25...1000, visible: 0.25...15)
        addSlider("outline", "Обводка", 0...1000, visible: 0...6)
        addSlider("opacity", "Непрозрачность", 0...1, visible: 0...1)
        let separator = NSBox()
        separator.boxType = .separator
        adjustments.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: adjustments.widthAnchor).isActive = true
        let displayHeading = NSTextField(labelWithString: "Экран и положение")
        displayHeading.font = .systemFont(ofSize: 14, weight: .semibold)
        adjustments.addArrangedSubview(displayHeading)
        screen.setAccessibilityLabel("Монитор для прицела")
        screen.cell?.lineBreakMode = .byTruncatingMiddle
        screen.target = self
        screen.action = #selector(changeScreen)
        row("Монитор", control: screen)
        addSlider("offsetX", "Смещение вправо", -10000...10000, visible: -200...200)
        addSlider("offsetY", "Смещение вверх", -10000...10000, visible: -200...200)
        let positionHint = NSTextField(labelWithString: "0, 0 — центр экрана · +X вправо · +Y вверх")
        positionHint.font = .systemFont(ofSize: 11)
        positionHint.textColor = .secondaryLabelColor
        adjustments.addArrangedSubview(positionHint)
        bindTranslations(in: content)
        refreshLanguage()
        // Fit the window to the two columns and their outer margins.
        window?.setContentSize(NSSize(width: content.fittingSize.width + 32, height: 460))
    }

    // Capture source strings once; language switches update existing controls in place.
    private func bindTranslations(in view: NSView) {
        if let label = view as? NSTextField, !label.isEditable {
            let source = label.stringValue
            languageUpdates.append { label.stringValue = L.text(source) }
        }
        if let button = view as? NSButton, !(button is NSPopUpButton) {
            let source = button.title
            languageUpdates.append { button.title = L.text(source) }
        }
        if let tooltip = view.toolTip {
            languageUpdates.append { view.toolTip = L.text(tooltip) }
        }
        if let label = view.accessibilityLabel() {
            languageUpdates.append { view.setAccessibilityLabel(L.text(label)) }
        }
        for child in view.subviews { bindTranslations(in: child) }
    }

    private func refreshLanguage() {
        window?.title = L.text("Настройки прицела")
        languageUpdates.forEach { $0() }
        for (index, title) in ["Крест", "Точка", "Кольцо"].enumerated() {
            style.setLabel(L.text(title), forSegment: index)
        }
        language.selectedSegment = L.language == "en" ? 1 : 0
        sync()
        refreshEnabled()
    }

    @objc private func changeLanguage() {
        guard window?.makeFirstResponder(nil) == true else {
            language.selectedSegment = L.language == "en" ? 1 : 0
            return
        }
        L.language = language.selectedSegment == 1 ? "en" : "ru"
        refreshLanguage()
        overlay.refreshLanguage()
    }

    @discardableResult
    private func row(_ title: String, control: NSView, column: NSStackView? = nil) -> NSTextField {
        let column = column ?? adjustments
        if control === screen {
            control.widthAnchor.constraint(equalToConstant: 204).isActive = true
            control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let label = NSTextField(labelWithString: title)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.widthAnchor.constraint(equalToConstant: column === appearance ? 110 : 128).isActive = true
        let stack = NSStackView(views: [label, control])
        stack.spacing = 8
        stack.alignment = .centerY
        column.addArrangedSubview(stack)
        stack.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        return label
    }

    private func addSlider(_ key: String, _ title: String, _ limits: ClosedRange<Double>, visible: ClosedRange<Double>) {
        self.limits[key] = limits
        let multiplier: Double = key == "opacity" ? 100 : 1
        let slider = NSSlider(value: 0, minValue: visible.lowerBound * multiplier, maxValue: visible.upperBound * multiplier,
                              target: self, action: #selector(changeNumber(_:)))
        slider.identifier = NSUserInterfaceItemIdentifier(key)
        slider.isContinuous = true
        slider.widthAnchor.constraint(equalToConstant: 116).isActive = true
        sliders[key] = slider
        slider.setAccessibilityLabel(title)
        let explanation = key == "opacity"
            ? "От 0 до 100 %. 0 % полностью скрывает прицел."
            : "Размеры в пунктах macOS. Точное значение можно ввести в поле справа."
        slider.toolTip = explanation
        let field = NSTextField()
        field.identifier = NSUserInterfaceItemIdentifier(key)
        field.delegate = self
        field.setAccessibilityLabel("\(title): точное значение")
        field.toolTip = explanation
        field.alignment = .right
        field.widthAnchor.constraint(equalToConstant: 56).isActive = true
        let formatter = NumberFormatter()
        formatter.minimum = NSNumber(value: limits.lowerBound * multiplier)
        formatter.maximum = NSNumber(value: limits.upperBound * multiplier)
        formatter.maximumFractionDigits = 2
        formatter.allowsFloats = true
        field.formatter = formatter
        values[key] = field
        let unit = NSTextField(labelWithString: key == "opacity" ? "%" : "pt")
        unit.font = .systemFont(ofSize: 11)
        unit.textColor = .secondaryLabelColor
        unit.widthAnchor.constraint(equalToConstant: 16).isActive = true
        rowLabels[key] = row(title, control: NSStackView(views: [slider, field, unit]))
    }

    private var numericKeys: [String: WritableKeyPath<Options, CGFloat>] {
        ["length": \.length, "gap": \.gap, "thickness": \.thickness,
         "radius": \.radius, "dotSize": \.dotSize, "outline": \.outline,
         "opacity": \.opacity, "offsetX": \.offsetX, "offsetY": \.offsetY]
    }

    private func sync() {
        let o = overlay.options
        style.selectedSegment = ["cross", "dot", "circle"].firstIndex(of: o.style) ?? 0
        colors[0].color = NSColor(rgbHex: o.color)
        colors[1].color = NSColor(rgbHex: o.outlineColor)
        centerDot.state = o.centerDot ? .on : .off
        for key in numericKeys.keys { syncNumber(key) }
        refreshAvailability()
        refreshScreens()
        refreshPreview()
    }

    private func syncNumber(_ key: String) {
        guard let path = numericKeys[key], let slider = sliders[key] else { return }
        let value = Double(overlay.options[keyPath: path]) * (key == "opacity" ? 100 : 1)
        slider.minValue = min(slider.minValue, value)
        slider.maxValue = max(slider.maxValue, value)
        slider.doubleValue = value
        values[key]?.doubleValue = value
    }

    private func refreshAvailability() {
        let o = overlay.options
        let availability = ["length": o.style == "cross", "gap": o.style == "cross",
                            "radius": o.style == "circle", "thickness": o.style != "dot",
                            "dotSize": o.style == "dot" || o.centerDot]
        for (key, available) in availability {
            sliders[key]?.isEnabled = available
            values[key]?.isEnabled = available
            rowLabels[key]?.textColor = available ? .labelColor : .disabledControlTextColor
        }
        centerDot.isEnabled = o.style != "dot"
        colors[1].isEnabled = o.outline > 0
    }

    @objc private func refreshScreens() {
        screen.removeAllItems()
        screen.addItem(withTitle: L.text("Главный монитор"))
        screen.lastItem?.representedObject = "main"
        screen.addItem(withTitle: L.text("Все мониторы"))
        screen.lastItem?.representedObject = "all"
        for (index, display) in NSScreen.screens.enumerated() {
            screen.addItem(withTitle: "\(index): \(display.localizedName)")
            screen.lastItem?.representedObject = String(index)
        }
        if let item = screen.itemArray.first(where: { ($0.representedObject as? String) == overlay.options.screen }) {
            screen.select(item)
        } else {
            screen.addItem(withTitle: L.format("Монитор %@ отключён", overlay.options.screen))
            screen.lastItem?.representedObject = overlay.options.screen
            screen.select(screen.lastItem)
        }
    }

    private func refreshPreview() {
        preview.subviews.forEach { $0.removeFromSuperview() }
        let view = CrosshairView(options: overlay.options)
        let size = overlay.options.canvasSize
        let scale = min(1, 172 / size, 88 / size)
        view.setFrameSize(NSSize(width: size * scale, height: size * scale))
        view.setBoundsSize(NSSize(width: size, height: size))
        view.translatesAutoresizingMaskIntoConstraints = false
        previewCaption.stringValue = overlay.options.opacity == 0
            ? L.text("Предпросмотр · прицел прозрачен при 0 %")
            : scale == 1 ? L.text("Предпросмотр · 1:1") : L.format("Предпросмотр · уменьшен до %d %%", Int(scale * 100))
        view.alphaValue = overlay.options.opacity
        preview.addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: preview.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: preview.centerYAnchor),
            view.widthAnchor.constraint(equalToConstant: size * scale),
            view.heightAnchor.constraint(equalToConstant: size * scale)
        ])
    }

    func refreshEnabled() {
        enabled.state = overlay.isEnabled ? .on : .off
        enabled.title = L.text(overlay.isEnabled ? "Прицел включён" : "Прицел выключен")
    }
    @objc private func toggle() { overlay.toggleEnabled() }
    @objc private func reset() {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = L.text("Сбросить настройки прицела?")
        alert.informativeText = L.text("Форма, цвета, размеры и положение вернутся к исходным значениям.")
        alert.addButton(withTitle: L.text("Отмена"))
        alert.addButton(withTitle: L.text("Сбросить"))
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertSecondButtonReturn, let self else { return }
            self.overlay.update(Options())
            self.sync()
        }
    }
    @objc private func changeStyle() {
        var o = overlay.options
        o.style = ["cross", "dot", "circle"][style.selectedSegment]
        overlay.update(o); refreshAvailability(); refreshPreview()
    }
    @objc private func changeDot() {
        var o = overlay.options
        o.centerDot = centerDot.state == .on
        overlay.update(o); refreshAvailability(); refreshPreview()
    }
    @objc private func changeScreen() {
        var o = overlay.options
        o.screen = screen.selectedItem?.representedObject as? String ?? "main"
        overlay.update(o)
    }
    @objc private func changeNumber(_ sender: NSControl) {
        guard let key = sender.identifier?.rawValue, let path = numericKeys[key] else { return }
        var o = overlay.options
        let rawValue = sender.doubleValue / (key == "opacity" ? 100 : 1)
        guard rawValue.isFinite, let range = limits[key] else { syncNumber(key); return }
        o[keyPath: path] = CGFloat(min(range.upperBound, max(range.lowerBound, rawValue)))
        overlay.update(o)
        syncNumber(key)
        refreshAvailability()
        refreshPreview()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.makeFirstResponder(nil)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        changeNumber(field)
    }

    @objc private func changeColor(_ sender: NSColorWell) {
        guard let color = sender.color.usingColorSpace(.sRGB) else { return }
        let hex = String(format: "%02X%02X%02X", Int((color.redComponent * 255).rounded()),
                         Int((color.greenComponent * 255).rounded()), Int((color.blueComponent * 255).rounded()))
        var o = overlay.options
        if sender.tag == 0 { o.color = hex } else { o.outlineColor = hex }
        overlay.update(o); refreshAvailability(); refreshPreview()
    }
}
