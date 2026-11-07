import Foundation

enum PreferencesMigration {
    /// Copy only our preferences, once. Leave the old app's domain intact.
    static func migrate(defaults: UserDefaults = .standard,
                        legacyDomains: [String] = ["local.luxora.CrosshairOverlay", "CrosshairOverlay"]) {
        let marker = "crosy.didMigratePreferences"
        guard !defaults.bool(forKey: marker) else { return }
        for domain in legacyDomains {
            let saved = defaults.persistentDomain(forName: domain) ?? [:]
            for key in ["crosshair.settings", "crosshair.language"] {
                if defaults.object(forKey: key) == nil, let value = saved[key] {
                    defaults.set(value, forKey: key)
                }
            }
        }
        defaults.set(true, forKey: marker)
    }
}
