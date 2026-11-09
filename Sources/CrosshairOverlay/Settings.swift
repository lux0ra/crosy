import AppKit
import Combine
import SwiftUI

/// Keep the existing accessory-app lifecycle and menu shortcuts; SwiftUI owns the window content.
@MainActor
final class SettingsController: NSWindowController, NSWindowDelegate {
    private var languageSubscription: AnyCancellable?

    init(model: SettingsModel) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = L.text("Настройки прицела")
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: SettingsView(model: model))
        super.init(window: window)
        window.delegate = self
        window.center()
        languageSubscription = model.$language.dropFirst().sink { [weak window] _ in
            window?.title = L.text("Настройки прицела")
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.makeFirstResponder(nil)
    }
}

@MainActor
struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var resetConfirmation = false
    @State private var displays = NSScreen.screens.enumerated().map { (id: String($0.offset), name: $0.element.localizedName) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                appearance
                    .frame(width: 216)
                ScrollView {
                    VStack(spacing: 12) {
                        geometryControls
                        displayControls
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 8) {
                Text(L.text("Настройки сохраняются автоматически."))
                    .font(.caption).foregroundStyle(.secondary)
                    .help(L.text("Закрытие окна оставляет прицел работать. Открыть настройки можно в строке меню."))
                Spacer(minLength: 0)
                visibilityButton
                    .fixedSize()
                Button(L.text("Сбросить настройки")) { resetConfirmation = true }
                    .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 680, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            displays = NSScreen.screens.enumerated().map { (id: String($0.offset), name: $0.element.localizedName) }
        }
        .alert(L.text("Сбросить настройки прицела?"), isPresented: $resetConfirmation) {
            Button(L.text("Отмена"), role: .cancel) {}
            Button(L.text("Сбросить"), role: .destructive) { model.update(Options()) }
        } message: {
            Text(L.text("Форма, цвета, размеры и положение вернутся к исходным значениям."))
        }
    }

    private var geometryControls: some View {
        GroupBox {
            VStack(spacing: 8) {
                ForEach(Array(NumericSetting.allCases.prefix(7)), id: \.self) { setting in
                    NumericSettingRow(model: model, setting: setting)
                }
            }.padding(8)
        }
        .accessibilityLabel(L.text("Геометрия прицела"))
    }

    private var displayControls: some View {
        GroupBox {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(L.text("Монитор"))
                        .font(.callout)
                        .frame(width: 118, alignment: .leading)
                    Picker(L.text("Монитор"), selection: binding(\.screen)) {
                        Text(L.text("Главный монитор")).tag("main")
                        Text(L.text("Все мониторы")).tag("all")
                        ForEach(displays, id: \.id) { display in
                            Text("\(display.id): \(display.name)").tag(display.id)
                        }
                        if !["main", "all"].contains(model.options.screen),
                           !displays.contains(where: { $0.id == model.options.screen }) {
                            Text(L.format("Монитор %@ отключён", model.options.screen))
                                .tag(model.options.screen)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(L.text("Монитор для прицела"))
                }
                NumericSettingRow(model: model, setting: .offsetX)
                NumericSettingRow(model: model, setting: .offsetY)
                Text(L.text("0, 0 — центр экрана · +X вправо · +Y вверх"))
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(8)
        }
        .accessibilityLabel(L.text("Экран и положение"))
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 12) {
            CrosshairPreview(options: model.options)
            Picker(L.text("Форма прицела"), selection: binding(\.style)) {
                Text(L.text("Крест")).tag("cross")
                Text(L.text("Точка")).tag("dot")
                Text(L.text("Кольцо")).tag("circle")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .help(L.text("Выберите форму. Доступные настройки справа зависят от неё."))
            VStack(alignment: .leading, spacing: 10) {
                ColorPicker(L.text("Цвет прицела"), selection: colorBinding(\.color), supportsOpacity: false)
                ColorPicker(L.text("Цвет обводки"), selection: colorBinding(\.outlineColor), supportsOpacity: false)
                    .disabled(model.options.outline == 0)
                HStack(spacing: 8) {
                    Text(L.text("Точка в центре"))
                    Toggle(L.text("Точка в центре"), isOn: binding(\.centerDot))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .fixedSize()
                }
                .disabled(model.options.style == "dot")
            }
            Divider()
            Picker(L.text("Язык"), selection: Binding(get: { model.language }, set: { model.setLanguage($0) })) {
                Text("RU").tag("ru")
                Text("EN").tag("en")
            }
            .pickerStyle(.segmented)
        }
        .controlSize(.regular)
    }

    private var visibilityButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                model.setEnabled(!model.isEnabled)
            }
        } label: {
            Text(L.text(model.isEnabled ? "Прицел включён" : "Прицел выключен"))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.bordered)
        .help(L.text("Скрыть или показать прицел, сохранив все настройки."))
        .accessibilityLabel(L.text("Видимость прицела"))
        .accessibilityValue(L.text(model.isEnabled ? "Прицел включён" : "Прицел выключен"))
    }

    private func binding<Value>(_ path: WritableKeyPath<Options, Value>) -> Binding<Value> {
        Binding(get: { model.options[keyPath: path] }, set: { value in
            var options = model.options
            options[keyPath: path] = value
            model.update(options)
        })
    }

    private func colorBinding(_ path: WritableKeyPath<Options, String>) -> Binding<Color> {
        Binding(get: { Color(nsColor: NSColor(rgbHex: model.options[keyPath: path])) }, set: { value in
            guard let color = NSColor(value).usingColorSpace(.sRGB) else { return }
            var options = model.options
            options[keyPath: path] = String(format: "%02X%02X%02X",
                Int((color.redComponent * 255).rounded()), Int((color.greenComponent * 255).rounded()),
                Int((color.blueComponent * 255).rounded()))
            model.update(options)
        })
    }
}

@MainActor
private struct NumericSettingRow: View {
    @ObservedObject var model: SettingsModel
    let setting: NumericSetting

    var body: some View {
        let value = model.number(setting)
        let binding = Binding(get: { model.number(setting) }, set: { model.setNumber(setting, to: $0) })
        let range = min(setting.sliderRange.lowerBound, value)...max(setting.sliderRange.upperBound, value)
        HStack(spacing: 8) {
            Text(L.text(setting.title))
                .font(.callout)
                .frame(width: 118, alignment: .leading)
            Slider(value: binding, in: range)
                .labelsHidden()
                .accessibilityLabel(L.text(setting.title))
            TextField(L.text(setting.title), value: binding, format: .number.precision(.fractionLength(0...2)))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .accessibilityLabel(L.text("\(setting.title): точное значение"))
            Text(setting == .opacity ? "%" : "pt")
                .font(.caption).foregroundStyle(.secondary).frame(width: 16)
        }
        .disabled(!setting.isAvailable(in: model.options))
        .help(L.text(setting == .opacity
            ? "От 0 до 100 %. 0 % полностью скрывает прицел."
            : "Размеры в пунктах macOS. Точное значение можно ввести в поле справа."))
    }
}
