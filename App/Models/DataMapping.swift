import Foundation
import SwiftData
import Core

// Conversions between SwiftData models and the Core transfer types.

extension WorkoutItem {
    var dto: WorkoutItemDTO {
        WorkoutItemDTO(id: id, order: order, exerciseName: exerciseName, equipment: equipment, kind: kind,
                       sets: sets, reps: reps, durationSec: durationSec, weightLb: weightLb,
                       warmupSets: warmupSets, warmupReps: warmupReps)
    }

    convenience init(dto: WorkoutItemDTO) {
        self.init(id: dto.id, order: dto.order, exerciseName: dto.exerciseName, equipment: dto.equipment,
                  kind: dto.kind, sets: dto.sets, reps: dto.reps, durationSec: dto.durationSec,
                  weightLb: dto.weightLb, warmupSets: dto.warmupSets, warmupReps: dto.warmupReps)
    }

    var activeExercise: ActiveExercise {
        ActiveExercise(id: id, name: exerciseName, equipment: equipment, kind: kind, weightLb: weightLb,
                       sets: sets, targetReps: reps, durationSec: durationSec,
                       warmupSets: warmupSets, warmupReps: warmupReps)
    }
}

extension Workout {
    var dto: WorkoutDTO {
        WorkoutDTO(id: id, name: name, createdAt: createdAt, items: sortedItems.map(\.dto))
    }

    /// Inserts a workout and its items from a transfer object.
    @discardableResult
    static func insert(_ dto: WorkoutDTO, into context: ModelContext) -> Workout {
        let workout = Workout(id: dto.id, name: dto.name, createdAt: dto.createdAt)
        context.insert(workout)
        for itemDTO in dto.items {
            let item = WorkoutItem(dto: itemDTO)
            context.insert(item)
            item.workout = workout
        }
        return workout
    }
}

extension Session {
    var dto: SessionDTO {
        SessionDTO(id: id, workoutID: workoutID, workoutName: workoutName, startedAt: startedAt, endedAt: endedAt,
                   entries: sortedEntries.map(\.dto))
    }

    @discardableResult
    static func insert(_ dto: SessionDTO, into context: ModelContext) -> Session {
        let session = Session(id: dto.id, workoutID: dto.workoutID, workoutName: dto.workoutName,
                              startedAt: dto.startedAt, endedAt: dto.endedAt)
        context.insert(session)
        for entryDTO in dto.entries {
            let entry = SessionEntry(order: entryDTO.order, exerciseName: entryDTO.exerciseName,
                                     equipment: entryDTO.equipment, kind: entryDTO.kind, weightLb: entryDTO.weightLb,
                                     targetReps: entryDTO.targetReps, targetDurationSec: entryDTO.targetDurationSec)
            context.insert(entry)
            entry.session = session
            for setDTO in entryDTO.sets {
                let log = SetLog(order: setDTO.order, isWarmup: setDTO.isWarmup, value: setDTO.value)
                context.insert(log)
                log.entry = entry
            }
        }
        return session
    }

    /// Builds the history record for a finished in-progress session. Only logged sets are kept.
    static func historyDTO(from active: ActiveSession, endedAt: Date) -> SessionDTO {
        let entries = active.exercises.enumerated().compactMap { index, ex -> SessionEntryDTO? in
            var sets: [SetDTO] = []
            for value in ex.warmups.compactMap({ $0 }) {
                sets.append(SetDTO(order: sets.count, isWarmup: true, value: value))
            }
            for value in ex.working.compactMap({ $0 }) {
                sets.append(SetDTO(order: sets.count, isWarmup: false, value: value))
            }
            guard !sets.isEmpty else { return nil }
            return SessionEntryDTO(order: index, exerciseName: ex.name, equipment: ex.equipment, kind: ex.kind,
                                   weightLb: ex.weightLb, targetReps: ex.targetReps,
                                   targetDurationSec: ex.durationSec, sets: sets)
        }
        return SessionDTO(id: active.id, workoutID: active.workoutID, workoutName: active.workoutName,
                          startedAt: active.startedAt, endedAt: endedAt, entries: entries)
    }
}

extension SessionEntry {
    var dto: SessionEntryDTO {
        SessionEntryDTO(order: order, exerciseName: exerciseName, equipment: equipment, kind: kind, weightLb: weightLb,
                        targetReps: targetReps, targetDurationSec: targetDurationSec,
                        sets: sortedSets.map { SetDTO(order: $0.order, isWarmup: $0.isWarmup, value: $0.value) })
    }
}

extension Exercise {
    var dto: ExerciseDTO {
        ExerciseDTO(name: name, equipment: equipment, kind: kind)
    }
}
