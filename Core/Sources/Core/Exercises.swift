import Foundation

public enum Equipment: String, Codable, CaseIterable, Identifiable, Sendable {
    case barbell, dumbbell, bodyweight, other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .bodyweight: return "Bodyweight"
        case .other: return "Other"
        }
    }

    /// Name prefix added to exercise names (SPEC 3.2, 4.2). "Other" adds none.
    public var namePrefix: String {
        self == .other ? "" : label + " "
    }
}

public enum ExerciseKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case reps, timed

    public var id: String { rawValue }

    public var label: String {
        self == .reps ? "Reps" : "Timed"
    }
}

public struct ExerciseDefinition: Equatable, Hashable, Sendable {
    public var name: String
    public var equipment: Equipment
    public var kind: ExerciseKind

    public init(name: String, equipment: Equipment, kind: ExerciseKind) {
        self.name = name
        self.equipment = equipment
        self.kind = kind
    }

    /// Builds a full name from a base name, adding the equipment prefix unless already present.
    public static func fullName(base: String, equipment: Equipment) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = equipment.namePrefix
        if prefix.isEmpty || trimmed.lowercased().hasPrefix(prefix.lowercased()) {
            return trimmed
        }
        return prefix + trimmed
    }
}

public enum BuiltInExercises {
    /// The 25 built-in exercises (SPEC 3).
    public static let all: [ExerciseDefinition] = {
        let barbell = ["Back Squat", "Front Squat", "Bench Press", "Incline Bench Press", "Overhead Press",
                       "Deadlift", "Romanian Deadlift", "Bent-Over Row", "Curl", "Hip Thrust"]
        let dumbbell = ["Bench Press", "Incline Bench Press", "Shoulder Press", "Row", "Curl",
                        "Hammer Curl", "Lateral Raise", "Lunge", "Goblet Squat", "Romanian Deadlift"]
        let bodyweight: [(String, ExerciseKind)] = [("Push-up", .reps), ("Pull-up", .reps), ("Chin-up", .reps),
                                                    ("Dip", .reps), ("Plank", .timed)]
        var list: [ExerciseDefinition] = []
        list += barbell.map { ExerciseDefinition(name: "Barbell " + $0, equipment: .barbell, kind: .reps) }
        list += dumbbell.map { ExerciseDefinition(name: "Dumbbell " + $0, equipment: .dumbbell, kind: .reps) }
        list += bodyweight.map { ExerciseDefinition(name: "Bodyweight " + $0.0, equipment: .bodyweight, kind: $0.1) }
        return list
    }()
}

/// Defaults applied when an exercise is added to a workout (SPEC 3.4–3.6).
public enum ExerciseDefaults {
    public static let sets = 3
    public static let reps = 10
    public static let durationSec = 60
    public static let warmupReps = 5

    public static func weightLb(for equipment: Equipment) -> Double {
        switch equipment {
        case .barbell: return 45
        case .dumbbell: return 20
        case .bodyweight, .other: return 0
        }
    }
}
