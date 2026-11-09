import AppKit

struct CLIError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

struct Options: Codable, Equatable {
    var style = "cross"
    var color = "00FF00"
    var outlineColor = "000000"
    var length: CGFloat = 10
    var gap: CGFloat = 4
    var thickness: CGFloat = 2
    var radius: CGFloat = 8
    var dotSize: CGFloat = 3
    var outline: CGFloat = 1
    var opacity: CGFloat = 1
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var screen = "main"
    var centerDot = false
    var help = false
    var listScreens = false

    static let usage = """
    Crosy — прозрачный прицел для macOS

    Запуск: Crosy [параметры]
      --style cross|dot|circle   Форма (cross)
      --color RRGGBB            Цвет (00FF00); '#' тоже допустим
      --length N                Длина каждого луча креста (10)
      --gap N                   Отступ от центра до луча (4)
      --thickness N             Толщина линий (2)
      --radius N                Радиус кольца (8)
      --dot-size N              Диаметр точки (3)
      --center-dot              Добавить точку к кресту или кольцу
      --outline N               Толщина обводки; 0 — без неё (1)
      --outline-color RRGGBB    Цвет обводки (000000)
      --opacity N               Прозрачность от 0 до 1 (1)
      --offset-x N              Смещение вправо в пунктах (0)
      --offset-y N              Смещение вверх в пунктах (0)
      --screen main|all|N       Главный, все или индекс монитора (main)
      --list-screens            Показать мониторы и выйти
      --help, -h                Эта справка

    Размеры — в пунктах macOS: на Retina один пункт занимает несколько пикселей.
    Остановка: Ctrl+C в терминале или SIGTERM процессу.
    """

    static func parse(_ arguments: [String]) throws -> Options {
        var result = Options()
        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            if flag == "--help" || flag == "-h" { result.help = true; index += 1; continue }
            if flag == "--list-screens" { result.listScreens = true; index += 1; continue }
            if flag == "--center-dot" { result.centerDot = true; index += 1; continue }
            let known = ["--style", "--color", "--outline-color", "--screen", "--length",
                         "--gap", "--thickness", "--radius", "--dot-size", "--outline",
                         "--opacity", "--offset-x", "--offset-y"]
            guard known.contains(flag) else { throw CLIError("Неизвестный параметр: \(flag)") }
            guard index + 1 < arguments.count else { throw CLIError("Нужно значение для \(flag)") }
            let value = arguments[index + 1]
            switch flag {
            case "--style":
                guard ["cross", "dot", "circle"].contains(value) else {
                    throw CLIError("--style: допустимы cross, dot, circle")
                }
                result.style = value
            case "--color", "--outline-color":
                let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
                guard hex.count == 6, hex.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
                    throw CLIError("\(flag): нужен HEX-цвет RRGGBB")
                }
                if flag == "--color" { result.color = hex } else { result.outlineColor = hex }
            case "--screen":
                guard value == "main" || value == "all" || (Int(value).map { $0 >= 0 } ?? false) else {
                    throw CLIError("--screen: укажите main, all или неотрицательный индекс")
                }
                result.screen = value
            default:
                guard let number = Double(value), number.isFinite else {
                    throw CLIError("\(flag): нужно конечное число")
                }
                let range: ClosedRange<Double>
                switch flag {
                case "--opacity": range = 0...1
                case "--offset-x", "--offset-y": range = -10000...10000
                case "--thickness", "--radius", "--dot-size": range = 0.25...1000
                default: range = 0...1000
                }
                guard range.contains(number) else {
                    throw CLIError("\(flag): значение должно быть в диапазоне \(range)")
                }
                let n = CGFloat(number)
                switch flag {
                case "--length": result.length = n
                case "--gap": result.gap = n
                case "--thickness": result.thickness = n
                case "--radius": result.radius = n
                case "--dot-size": result.dotSize = n
                case "--outline": result.outline = n
                case "--opacity": result.opacity = n
                case "--offset-x": result.offsetX = n
                case "--offset-y": result.offsetY = n
                default: break
                }
            }
            index += 2
        }
        return result
    }

    var canvasSize: CGFloat {
        2 * (max(gap + length, radius + thickness / 2, dotSize / 2) + outline + 4)
    }
}

extension NSColor {
    convenience init(rgbHex: String) {
        let value = UInt32(rgbHex, radix: 16)!
        self.init(srgbRed: CGFloat((value >> 16) & 255) / 255,
                  green: CGFloat((value >> 8) & 255) / 255,
                  blue: CGFloat(value & 255) / 255, alpha: 1)
    }
}
