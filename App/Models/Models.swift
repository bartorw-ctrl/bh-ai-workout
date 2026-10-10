import Foundation
import SwiftData
import Core

// All properties have defaults and relationships are optional so CloudKit sync can be turned on in v2 (SPEC 0.3).

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var equipmentRaw: String = Equipment.barbell.rawValue
    var kindRaw: String = ExerciseKind.reps.rawValue
    var isBuiltIn: Bool = false

    init(name: String, equipment: Equipment, kind: ExerciseKind, isBuiltIn: Bool) {
        self.name = name
        self.equipmentRaw = equipment.rawValue
        self.kindRaw = kind.rawValue
        self.isBuiltIn = isBuiltIn
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }

    var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRaw) ?? .reps }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class Workout {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \WorkoutItem.workout)
    var items: [WorkoutItem]? = []

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    var sortedItems: [WorkoutItem] {
        (items ?? []).sorted { $0.order < $1.order }
    }
}

/// One exercise inside a workout. The exercise is copied by name so deleting a custom exercise never breaks a workout.
@Model
final class WorkoutItem {
    var id: UUID = UUID()
    var order: Int = 0
    var exerciseName: String = ""
    var equipmentRaw: String = Equipment.barbell.rawValue
    var kindRaw: String = ExerciseKind.reps.rawValue
    var sets: Int = 3
    var reps: Int = 10
    var durationSec: Int = 60
    var weightLb: Double = 0
    var warmupSets: Int = 0
    var warmupReps: Int = 5
    var workout: Workout?

    init(id: UUID = UUID(), order: Int, exerciseName: String, equipment: Equipment, kind: ExerciseKind,
         sets: Int, reps: Int, durationSec: Int, weightLb: Double, warmupSets: Int, warmupReps: Int) {
        self.id = id
        self.order = order
        self.exerciseName = exerciseName
        self.equipmentRaw = equipment.rawValue
        self.kindRaw = kind.rawValue
        self.sets = sets
        self.reps = reps
        self.durationSec = durationSec
        self.weightLb = weightLb
        self.warmupSets = warmupSets
        self.warmupReps = warmupReps
    }

    var equipment: Equipment { Equipment(rawValue: equipmentRaw) ?? .other }
    var kind: ExerciseKind { ExerciseKind(rawValue: kindRaw) ?? .reps }
}

/// A completed workout in history.
@Model
final class Session {
    var id: UUID = UUID()
    var workoutID: UUID?
    var workoutName: String = ""
    var startedAt: Date = Date()
    var endedAt: Date = Date()
    var healthKitID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \SessionEntry.session)
    var entries: [SessionEntry]? = []

    init(id: UUID = UUID(), workoutID: UUID?, workoutName: String, startedAt: Date, endedAt: Date) {
        self.id = id
        self.workoutID = workoutID
        self.workoutName = workoutName
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var sortedEntries: [SessionEntry] {
        (entries ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class SessionEntry {
    var id: UUID = UUID()
    var order: Int = 0
    var exerciseName: String = ""
    var equipmentRaw: String = Equipment.barbell.rawValue
    var kindRaw: String = ExerciseKind.reps.rawValue
    var weightLb: Double = 0
    var targetReps: Int = 10
    var targetDurationSec: Int = 60
    var session: Session?
    @Relationship(deleteRule: .cascade, inverse: \SetLog.entry)
    var sets: [SetLog]? = []

    init(order: Int, exerciseName: String, equipment: Equipment, kind: ExerciseKind, weightLb: Double,
         targetReps: Int, targetDurationSec: Int) {
        self.order = order
        self.exerciseName = exerciseName
        self.equipmentRaw = equipment.rawValue
        self.kindRaw = kind.rawValue
        self.weightLb = weightLb
        self.targetReps = targetReps
        self.targetDurationSec = targetDurationSec
    }

    var equipment: Equipment { Equipment(rawValue: equipmentRaw) ?? .other }
    var kind: ExerciseKind { ExerciseKind(rawValue: kindRaw) ?? .reps }

    var sortedSets: [SetLog] {
        (sets ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class SetLog {
    var id: UUID = UUID()
    var order: Int = 0
    var isWarmup: Bool = false
    /// Reps, or seconds for timed exercises.
    var value: Int = 0
    var entry: SessionEntry?

    init(order: Int, isWarmup: Bool, value: Int) {
        self.order = order
        self.isWarmup = isWarmup
        self.value = value
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Exercise.self, Workout.self, WorkoutItem.self, Session.self, SessionEntry.self, SetLog.self
    ]
}
