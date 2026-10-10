import Foundation

/// Rules for tapping a rep set circle (SPEC 5.3):
/// empty → target reps, then one rep fewer per tap, then back to empty after 0.
public enum SetTap {
    public static func next(current: Int?, target: Int) -> Int? {
        guard let current else { return target }
        return current > 0 ? current - 1 : nil
    }
}

public struct RunningTimer: Codable, Equatable, Sendable {
    public var exerciseIndex: Int
    public var setIndex: Int
    public var startedAt: Date
    public var durationSec: Int

    public var endsAt: Date { startedAt.addingTimeInterval(TimeInterval(durationSec)) }

    public func remaining(at now: Date) -> Int {
        max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
    }

    public func elapsed(at now: Date) -> Int {
        min(durationSec, max(0, Int(now.timeIntervalSince(startedAt))))
    }
}

public struct ActiveExercise: Codable, Equatable, Identifiable, Sendable {
    /// The workout item this came from, so weights can be written back on finish (SPEC 5.7).
    public var id: UUID
    public var name: String
    public var equipment: Equipment
    public var kind: ExerciseKind
    public var weightLb: Double
    public var targetReps: Int
    public var durationSec: Int
    public var warmupReps: Int
    /// Logged value per working set: reps, or seconds for timed. nil = not done.
    public var working: [Int?]
    public var warmups: [Int?]

    public init(id: UUID, name: String, equipment: Equipment, kind: ExerciseKind, weightLb: Double,
                sets: Int, targetReps: Int, durationSec: Int, warmupSets: Int, warmupReps: Int) {
        self.id = id
        self.name = name
        self.equipment = equipment
        self.kind = kind
        self.weightLb = weightLb
        self.targetReps = targetReps
        self.durationSec = durationSec
        self.warmupReps = warmupReps
        self.working = Array(repeating: nil, count: max(0, sets))
        // Warm-ups apply to rep exercises only (SPEC 3.7).
        self.warmups = Array(repeating: nil, count: kind == .reps ? max(0, warmupSets) : 0)
    }

    public var isBodyweight: Bool { equipment == .bodyweight }

    /// Target for a working set: reps, or seconds when timed.
    public var workingTarget: Int { kind == .timed ? durationSec : targetReps }
}

/// The in-progress workout. Persisted to disk so it survives the app being killed (SPEC 5.12).
public struct ActiveSession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var workoutID: UUID?
    public var workoutName: String
    public var startedAt: Date
    public var exercises: [ActiveExercise]
    public var running: RunningTimer?
    public var restEndsAt: Date?
    public var restTotalSec: Int

    public init(id: UUID = UUID(), workoutID: UUID?, workoutName: String, startedAt: Date,
                exercises: [ActiveExercise]) {
        self.id = id
        self.workoutID = workoutID
        self.workoutName = workoutName
        self.startedAt = startedAt
        self.exercises = exercises
        self.running = nil
        self.restEndsAt = nil
        self.restTotalSec = 0
    }

    // MARK: Rest timer (SPEC 5.8)

    public func restRemaining(at now: Date) -> Int? {
        guard let restEndsAt, restEndsAt > now else { return nil }
        return Int(restEndsAt.timeIntervalSince(now).rounded(.up))
    }

    public mutating func startRest(at start: Date, seconds: Int) {
        restTotalSec = seconds
        restEndsAt = start.addingTimeInterval(TimeInterval(seconds))
    }

    public mutating func addRest(seconds: Int, now: Date) {
        guard let restEndsAt, restEndsAt > now else { return }
        self.restEndsAt = restEndsAt.addingTimeInterval(TimeInterval(seconds))
        restTotalSec += seconds
    }

    public mutating func skipRest() {
        restEndsAt = nil
    }

    // MARK: Taps

    /// Tap on a working set. Starts the rest timer when a set becomes done.
    public mutating func tapWorking(exercise e: Int, set s: Int, now: Date, restSeconds: Int) {
        guard exercises.indices.contains(e), exercises[e].working.indices.contains(s) else { return }
        let ex = exercises[e]
        if ex.kind == .timed {
            tapTimed(exercise: e, set: s, now: now, restSeconds: restSeconds)
            return
        }
        let current = ex.working[s]
        exercises[e].working[s] = SetTap.next(current: current, target: ex.targetReps)
        if current == nil {
            startRest(at: now, seconds: restSeconds)
        }
    }

    /// Tap on a warm-up set. Never starts the rest timer (SPEC 5.8).
    public mutating func tapWarmup(exercise e: Int, set s: Int) {
        guard exercises.indices.contains(e), exercises[e].warmups.indices.contains(s) else { return }
        let ex = exercises[e]
        exercises[e].warmups[s] = SetTap.next(current: ex.warmups[s], target: ex.warmupReps)
    }

    /// Timed sets (SPEC 5.4): start countdown; tap while running stops early; tap done set resets.
    private mutating func tapTimed(exercise e: Int, set s: Int, now: Date, restSeconds: Int) {
        if let running, running.exerciseIndex == e, running.setIndex == s {
            exercises[e].working[s] = running.elapsed(at: now)
            self.running = nil
            startRest(at: now, seconds: restSeconds)
            return
        }
        if exercises[e].working[s] != nil {
            exercises[e].working[s] = nil
            return
        }
        // Starting a new timer finishes any other running one with its elapsed time.
        if let other = running {
            exercises[other.exerciseIndex].working[other.setIndex] = other.elapsed(at: now)
        }
        running = RunningTimer(exerciseIndex: e, setIndex: s, startedAt: now, durationSec: exercises[e].durationSec)
        restEndsAt = nil
    }

    /// Advances timers. Returns true when the rest timer ran out during this call.
    @discardableResult
    public mutating func tick(now: Date, restSeconds: Int) -> Bool {
        if let running, running.endsAt <= now {
            exercises[running.exerciseIndex].working[running.setIndex] = running.durationSec
            self.running = nil
            // Rest is measured from when the set actually ended, even if the app was in the background.
            startRest(at: running.endsAt, seconds: restSeconds)
        }
        if let restEndsAt, restEndsAt <= now {
            self.restEndsAt = nil
            return true
        }
        return false
    }

    /// When the next "rest over" alert should fire, if any. Used to schedule the notification (SPEC 5.9).
    public func nextRestAlert(restSeconds: Int, now: Date) -> Date? {
        if let restEndsAt, restEndsAt > now { return restEndsAt }
        if let running {
            return running.endsAt.addingTimeInterval(TimeInterval(restSeconds))
        }
        return nil
    }

    // MARK: Weight (SPEC 5.6)

    public mutating func changeWeight(exercise e: Int, steps: Int, unit: WeightUnit) {
        guard exercises.indices.contains(e) else { return }
        exercises[e].weightLb = WeightFormat.step(exercises[e].weightLb, by: steps, unit: unit)
    }

    // MARK: Summary

    public var loggedSetCount: Int {
        exercises.reduce(0) { total, ex in
            total + ex.working.compactMap { $0 }.count + ex.warmups.compactMap { $0 }.count
        }
    }
}
