import Foundation
import Core

/// UserDefaults keys used with @AppStorage (SPEC 9.1, 9.2, 9.8).
enum SettingsKey {
    static let unit = "unit"
    static let restSeconds = "restSeconds"
    static let healthEnabled = "healthEnabled"
}

enum SettingsDefault {
    static let unit = WeightUnit.lb.rawValue
    static let restSeconds = 90
    static let healthEnabled = true
}

enum AppSettings {
    static var unit: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: SettingsKey.unit) ?? SettingsDefault.unit) ?? .lb
    }

    static var restSeconds: Int {
        (UserDefaults.standard.object(forKey: SettingsKey.restSeconds) as? Int) ?? SettingsDefault.restSeconds
    }

    static var healthEnabled: Bool {
        (UserDefaults.standard.object(forKey: SettingsKey.healthEnabled) as? Bool) ?? SettingsDefault.healthEnabled
    }
}

enum Summary {
    /// "3 × 10", "3 × 60s", "3 × 10 · 1 warm-up × 5"
    static func sets(kind: ExerciseKind, sets: Int, reps: Int, durationSec: Int, warmupSets: Int, warmupReps: Int) -> String {
        var text = kind == .timed ? "\(sets) × \(durationSec)s" : "\(sets) × \(reps)"
        if kind == .reps && warmupSets > 0 {
            text += " · \(warmupSets) warm-up × \(warmupReps)"
        }
        return text
    }
}
