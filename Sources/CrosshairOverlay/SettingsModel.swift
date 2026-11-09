import AppKit
import Combine

/// The single source of truth shared by SwiftUI and the AppKit overlay.
@MainActor
final class SettingsModel: ObservableObject {
    @Published private(set) var options: Options
    @Published private(set) var isEnabled = true
    @Published private(set) var language: String
    private let defaults: UserDefaults
    private let persists: Bool

    init(options: Options, persists: Bool, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.persists = persists
        language = defaults.string(forKey: "crosshair.language") == "en" ? "en" : "ru"
        if persists, let data = defaults.data(forKey: "crosshair.settings"),
           let saved = try? JSONDecoder().decode(Options.self, from: data) {
            self.options = saved
        } else {
            self.options = options
        }
    }

    func update(_ value: Options) {
        guard value != options else { return }
        if persists, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: "crosshair.settings")
        }
        options = value
    }

    func setEnabled(_ value: Bool) {
        guard value != isEnabled else { return }
        isEnabled = value
    }

    func setLanguage(_ value: String) {
        let value = value == "en" ? "en" : "ru"
        guard value != language else { return }
        defaults.set(value, forKey: "crosshair.language")
        language = value
    }
}

/// UI ranges stay compact; exact input retains the full existing CLI range.
enum NumericSetting: String, CaseIterable {
    case length, gap, thickness, radius, dotSize, outline, opacity, offsetX, offsetY

    var title: String {
        switch self {
        case .length: "Длина лучей"
        case .gap: "Отступ от центра"
        case .thickness: "Толщина"
        case .radius: "Радиус кольца"
        case .dotSize: "Размер точки"
        case .outline: "Обводка"
        case .opacity: "Непрозрачность"
        case .offsetX: "Смещение вправо"
        case .offsetY: "Смещение вверх"
        }
    }

    var path: WritableKeyPath<Options, CGFloat> {
        switch self {
        case .length: \.length
        case .gap: \.gap
        case .thickness: \.thickness
        case .radius: \.radius
        case .dotSize: \.dotSize
        case .outline: \.outline
        case .opacity: \.opacity
        case .offsetX: \.offsetX
        case .offsetY: \.offsetY
        }
    }

    var multiplier: Double { self == .opacity ? 100 : 1 }
    var limits: ClosedRange<Double> {
        switch self {
        case .opacity: 0...100
        case .offsetX, .offsetY: -10000...10000
        case .thickness, .radius, .dotSize: 0.25...1000
        default: 0...1000
        }
    }
    var sliderRange: ClosedRange<Double> {
        switch self {
        case .length: 0...40
        case .gap: 0...30
        case .thickness: 0.25...10
        case .radius: 0.25...40
        case .dotSize: 0.25...15
        case .outline: 0...6
        case .opacity: 0...100
        case .offsetX, .offsetY: -200...200
        }
    }

    func isAvailable(in options: Options) -> Bool {
        switch self {
        case .length, .gap: options.style == "cross"
        case .thickness: options.style != "dot"
        case .radius: options.style == "circle"
        case .dotSize: options.style == "dot" || options.centerDot
        default: true
        }
    }
}

extension SettingsModel {
    func number(_ setting: NumericSetting) -> Double {
        Double(options[keyPath: setting.path]) * setting.multiplier
    }

    func setNumber(_ setting: NumericSetting, to value: Double) {
        guard value.isFinite else { return }
        var updated = options
        updated[keyPath: setting.path] = CGFloat(min(setting.limits.upperBound,
            max(setting.limits.lowerBound, value)) / setting.multiplier)
        update(updated)
    }
}
