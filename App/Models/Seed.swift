import Foundation
import SwiftData
import Core

/// First-launch data: the built-in exercises and the sample workout (SPEC 1.2, 2.7).
enum Seed {
    private static let seededKey = "didSeedV1"

    static func runIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }
        insertBuiltIns(context: context)
        insertSampleWorkout(context: context)
        try? context.save()
        defaults.set(true, forKey: seededKey)
    }

    static func insertBuiltIns(context: ModelContext) {
        for def in BuiltInExercises.all {
            context.insert(Exercise(name: def.name, equipment: def.equipment, kind: def.kind, isBuiltIn: true))
        }
    }

    static func insertSampleWorkout(context: ModelContext) {
        let workout = Workout(name: "Full Body A")
        context.insert(workout)
        let items: [(String, Equipment, ExerciseKind, Double)] = [
            ("Barbell Back Squat", .barbell, .reps, 45),
            ("Barbell Bench Press", .barbell, .reps, 45),
            ("Barbell Bent-Over Row", .barbell, .reps, 45),
            ("Bodyweight Plank", .bodyweight, .timed, 0)
        ]
        for (index, entry) in items.enumerated() {
            let item = WorkoutItem(order: index, exerciseName: entry.0, equipment: entry.1, kind: entry.2,
                                   sets: ExerciseDefaults.sets, reps: ExerciseDefaults.reps,
                                   durationSec: ExerciseDefaults.durationSec, weightLb: entry.3,
                                   warmupSets: 0, warmupReps: ExerciseDefaults.warmupReps)
            context.insert(item)
            item.workout = workout
        }
    }
}
