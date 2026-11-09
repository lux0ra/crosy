import XCTest
import Combine
@testable import Crosy

final class CrosyTests: XCTestCase {
    func testCLIValidationAndGeometry() throws {
        let options = try Options.parse(["--style", "circle", "--radius", "9", "--color", "#ABCDEF",
                                         "--screen", "all", "--opacity", "0.8"])
        XCTAssertEqual(options.style, "circle")
        XCTAssertEqual(options.color, "ABCDEF")
        XCTAssertEqual(options.screen, "all")
        XCTAssertEqual(options.opacity, 0.8, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(options.canvasSize, 2 * (options.radius + options.thickness / 2 + options.outline))
        for arguments in [["--opacity", "nan"], ["--radius", "0"], ["--color", "GGGGGG"],
                          ["--screen", "-1"], ["--length"], ["--unknown"]] {
            XCTAssertThrowsError(try Options.parse(arguments))
        }
    }

    func testOptionsRoundTripPreservesSettings() throws {
        let options = try Options.parse(["--center-dot", "--offset-x", "-120", "--screen", "1"])
        let data = try JSONEncoder().encode(options)
        let restored = try JSONDecoder().decode(Options.self, from: data)
        XCTAssertTrue(restored.centerDot)
        XCTAssertEqual(restored.offsetX, -120)
        XCTAssertEqual(restored.screen, "1")
    }

    func testMigrationCopiesOnceWithoutOverwritingNewSettings() throws {
        let suite = "lol.luxora.crosy.tests.\(UUID().uuidString)"
        let legacy = suite + ".legacy"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            defaults.removePersistentDomain(forName: legacy)
        }
        let data = try JSONEncoder().encode(Options.parse(["--length", "22"]))
        defaults.setPersistentDomain(["crosshair.settings": data, "crosshair.language": "en",
                                      "unrelated": "ignore"], forName: legacy)
        defaults.set("ru", forKey: "crosshair.language")
        PreferencesMigration.migrate(defaults: defaults, legacyDomains: [legacy])
        XCTAssertEqual(defaults.data(forKey: "crosshair.settings"), data)
        XCTAssertEqual(defaults.string(forKey: "crosshair.language"), "ru")
        XCTAssertNil(defaults.object(forKey: "unrelated"))
        defaults.removeObject(forKey: "crosshair.settings")
        PreferencesMigration.migrate(defaults: defaults, legacyDomains: [legacy])
        XCTAssertNil(defaults.object(forKey: "crosshair.settings"))
    }

    func testSharedStatePersistsAndResetKeepsLanguage() throws {
        try MainActor.assumeIsolated {
            let suite = "lol.luxora.crosy.tests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let model = SettingsModel(options: Options(), persists: true, defaults: defaults)
            model.setLanguage("en")
            model.setNumber(.length, to: 32)
            model.setNumber(.opacity, to: 45)
            var changed = model.options
            changed.color = "ABCDEF"
            changed.screen = "all"
            changed.centerDot = true
            model.update(changed)
            let reloaded = SettingsModel(options: Options(), persists: true, defaults: defaults)
            XCTAssertEqual(reloaded.options, changed)
            XCTAssertEqual(reloaded.options.opacity, 0.45, accuracy: 0.0001)
            model.update(Options())
            XCTAssertEqual(model.language, "en")
            XCTAssertEqual(defaults.string(forKey: "crosshair.language"), "en")
            XCTAssertEqual(SettingsModel(options: changed, persists: true, defaults: defaults).options, Options())
        }
    }

    func testNumericValidationAndAvailability() throws {
        try MainActor.assumeIsolated {
            let suite = "lol.luxora.crosy.tests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let model = SettingsModel(options: Options(), persists: false, defaults: defaults)
            model.setNumber(.length, to: 700)
            XCTAssertEqual(model.number(.length), 700)
            model.setNumber(.length, to: .nan)
            XCTAssertEqual(model.number(.length), 700)
            model.setNumber(.thickness, to: -5)
            XCTAssertEqual(model.number(.thickness), 0.25)
            model.setNumber(.opacity, to: 200)
            XCTAssertEqual(model.options.opacity, 1)
            model.setNumber(.offsetX, to: -20000)
            XCTAssertEqual(model.options.offsetX, -10000)
            var options = model.options
            options.style = "dot"
            XCTAssertFalse(NumericSetting.length.isAvailable(in: options))
            XCTAssertFalse(NumericSetting.radius.isAvailable(in: options))
            XCTAssertTrue(NumericSetting.dotSize.isAvailable(in: options))
            XCTAssertNil(defaults.data(forKey: "crosshair.settings"))
        }
    }

    func testCLIStateIgnoresSavedSettingsAndSkipsIdenticalUpdates() throws {
        try MainActor.assumeIsolated {
            let suite = "lol.luxora.crosy.tests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            let saved = try JSONEncoder().encode(Options.parse(["--length", "88"]))
            defaults.set(saved, forKey: "crosshair.settings")
            let supplied = try Options.parse(["--length", "14"])
            let model = SettingsModel(options: supplied, persists: false, defaults: defaults)
            XCTAssertEqual(model.options, supplied)
            var emissions = 0
            let subscription = model.$options.dropFirst().sink { _ in emissions += 1 }
            model.update(supplied)
            XCTAssertEqual(emissions, 0)
            model.setNumber(.length, to: 15)
            XCTAssertEqual(emissions, 1)
            XCTAssertEqual(defaults.data(forKey: "crosshair.settings"), saved)
            model.setEnabled(false)
            XCTAssertFalse(model.isEnabled)
            withExtendedLifetime(subscription) {}
        }
    }

}
