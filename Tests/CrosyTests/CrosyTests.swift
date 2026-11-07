import XCTest
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
}
