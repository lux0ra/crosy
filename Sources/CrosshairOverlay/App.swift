import AppKit

@main
enum CrosshairOverlayApp {
    @MainActor
    static func main() {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst()).filter { !$0.hasPrefix("-psn_") }
            let usesSettings = arguments.isEmpty
            let options = try Options.parse(arguments)
            if options.help { print(Options.usage); return }
            let app = NSApplication.shared
            app.setActivationPolicy(usesSettings ? .accessory : .prohibited)
            if options.listScreens {
                for (index, screen) in NSScreen.screens.enumerated() {
                    let frame = screen.frame
                    print("\(index): \(screen.localizedName) — \(Int(frame.width))×\(Int(frame.height)) pt, scale \(screen.backingScaleFactor)\(index == 0 ? " [main]" : "")")
                }
                return
            }
            guard !NSScreen.screens.isEmpty else { throw CLIError("Нет доступных мониторов в графической сессии") }
            if let index = Int(options.screen), !NSScreen.screens.indices.contains(index) {
                throw CLIError("Монитор \(index) не найден. Посмотрите --list-screens")
            }
            let controller = OverlayController(options: options, usesSettings: usesSettings)
            app.delegate = controller
            withExtendedLifetime(controller) { app.run() }
        } catch {
            FileHandle.standardError.write(Data("Ошибка: \(error)\nСправка: CrosshairOverlay --help\n".utf8))
            exit(2)
        }
    }
}
