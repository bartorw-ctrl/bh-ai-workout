import Foundation

// MARK: - File format (SPEC 9.4–9.7)

public struct ExportFile: Codable, Equatable, Sendable {
    public static let appName = "BH AI Workout"
    public static let currentVersion = 1

    public var app: String
    public var formatVersion: Int
    public var exportedAt: Date
    public var settings: SettingsDTO
    public var customExercises: [ExerciseDTO]
    public var workouts: [WorkoutDTO]
    public var sessions: [SessionDTO]

    public init(exportedAt: Date, settings: SettingsDTO, customExercises: [ExerciseDTO],
                workouts: [WorkoutDTO], sessions: [SessionDTO]) {
        self.app = ExportFile.appName
        self.formatVersion = ExportFile.currentVersion
        self.exportedAt = exportedAt
        self.settings = settings
        self.customExercises = customExercises
        self.workouts = workouts
        self.sessions = sessions
    }
}

public struct SettingsDTO: Codable, Equatable, Sendable {
    public var unit: WeightUnit
    public var restSeconds: Int

    public init(unit: WeightUnit, restSeconds: Int) {
        self.unit = unit
        self.restSeconds = restSeconds
    }
}

public struct ExerciseDTO: Codable, Equatable, Sendable {
    public var name: String
    public var equipment: Equipment
    public var kind: ExerciseKind

    public init(name: String, equipment: Equipment, kind: ExerciseKind) {
        self.name = name
        self.equipment = equipment
        self.kind = kind
    }
}

public struct WorkoutDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var items: [WorkoutItemDTO]

    public init(id: UUID, name: String, createdAt: Date, items: [WorkoutItemDTO]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.items = items
    }
}

public struct WorkoutItemDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var order: Int
    public var exerciseName: String
    public var equipment: Equipment
    public var kind: ExerciseKind
    public var sets: Int
    public var reps: Int
    public var durationSec: Int
    public var weightLb: Double
    public var warmupSets: Int
    public var warmupReps: Int

    public init(id: UUID, order: Int, exerciseName: String, equipment: Equipment, kind: ExerciseKind,
                sets: Int, reps: Int, durationSec: Int, weightLb: Double, warmupSets: Int, warmupReps: Int) {
        self.id = id
        self.order = order
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.kind = kind
        self.sets = sets
        self.reps = reps
        self.durationSec = durationSec
        self.weightLb = weightLb
        self.warmupSets = warmupSets
        self.warmupReps = warmupReps
    }
}

public struct SessionDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var workoutID: UUID?
    public var workoutName: String
    public var startedAt: Date
    public var endedAt: Date
    public var entries: [SessionEntryDTO]

    public init(id: UUID, workoutID: UUID?, workoutName: String, startedAt: Date, endedAt: Date,
                entries: [SessionEntryDTO]) {
        self.id = id
        self.workoutID = workoutID
        self.workoutName = workoutName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.entries = entries
    }
}

public struct SessionEntryDTO: Codable, Equatable, Sendable {
    public var order: Int
    public var exerciseName: String
    public var equipment: Equipment
    public var kind: ExerciseKind
    public var weightLb: Double
    public var targetReps: Int
    public var targetDurationSec: Int
    public var sets: [SetDTO]

    public init(order: Int, exerciseName: String, equipment: Equipment, kind: ExerciseKind, weightLb: Double,
                targetReps: Int, targetDurationSec: Int, sets: [SetDTO]) {
        self.order = order
        self.exerciseName = exerciseName
        self.equipment = equipment
        self.kind = kind
        self.weightLb = weightLb
        self.targetReps = targetReps
        self.targetDurationSec = targetDurationSec
        self.sets = sets
    }
}

public struct SetDTO: Codable, Equatable, Sendable {
    public var order: Int
    public var isWarmup: Bool
    /// Reps, or seconds for timed exercises.
    public var value: Int

    public init(order: Int, isWarmup: Bool, value: Int) {
        self.order = order
        self.isWarmup = isWarmup
        self.value = value
    }
}

// MARK: - JSON

public enum TransferError: Error, Equatable, LocalizedError {
    case notAnExport
    case unsupportedVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .notAnExport:
            return "This file isn't a BH AI Workout export."
        case .unsupportedVersion(let v):
            return "This export uses format version \(v), which this version of the app can't read."
        }
    }
}

public enum JSONTransfer {
    public static func encode(_ file: ExportFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    /// Decodes and validates an export (SPEC 9.7). Throws on anything unrecognised.
    public static func decode(_ data: Data) throws -> ExportFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file: ExportFile
        do {
            file = try decoder.decode(ExportFile.self, from: data)
        } catch {
            throw TransferError.notAnExport
        }
        guard file.app == ExportFile.appName else { throw TransferError.notAnExport }
        guard file.formatVersion <= ExportFile.currentVersion else {
            throw TransferError.unsupportedVersion(file.formatVersion)
        }
        return file
    }
}

// MARK: - Import preview & merge (SPEC 9.5, 9.6)

public struct ImportPreview: Equatable, Sendable {
    public var workoutCount: Int
    public var sessionCount: Int
    public var customExerciseCount: Int
    public var firstSession: Date?
    public var lastSession: Date?

    public init(file: ExportFile) {
        workoutCount = file.workouts.count
        sessionCount = file.sessions.count
        customExerciseCount = file.customExercises.count
        firstSession = file.sessions.map(\.startedAt).min()
        lastSession = file.sessions.map(\.startedAt).max()
    }
}

public enum ImportMode: String, CaseIterable, Identifiable, Sendable {
    case merge, replace
    public var id: String { rawValue }
}

public struct ImportPlan: Equatable, Sendable {
    public var exercises: [ExerciseDTO]
    public var workouts: [WorkoutDTO]
    public var sessions: [SessionDTO]

    /// Merge keeps existing data and adds only items not already present (matched by ID, or name for exercises).
    /// Replace takes everything from the file.
    public static func make(file: ExportFile, mode: ImportMode, existingExerciseNames: Set<String>,
                            existingWorkoutIDs: Set<UUID>, existingSessionIDs: Set<UUID>) -> ImportPlan {
        switch mode {
        case .replace:
            return ImportPlan(exercises: file.customExercises, workouts: file.workouts, sessions: file.sessions)
        case .merge:
            let names = Set(existingExerciseNames.map { $0.lowercased() })
            return ImportPlan(
                exercises: file.customExercises.filter { !names.contains($0.name.lowercased()) },
                workouts: file.workouts.filter { !existingWorkoutIDs.contains($0.id) },
                sessions: file.sessions.filter { !existingSessionIDs.contains($0.id) }
            )
        }
    }
}

// MARK: - CSV (SPEC 9.4: one row per set)

public enum CSVExport {
    public static let header = ["date", "start_time", "workout", "exercise", "set_type", "set_number",
                                "reps", "duration_sec", "weight", "unit"]

    public static func make(sessions: [SessionDTO], unit: WeightUnit, timeZone: TimeZone = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = timeZone
        timeFormatter.dateFormat = "HH:mm"

        var lines = [header.joined(separator: ",")]
        for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            let date = dateFormatter.string(from: session.startedAt)
            let time = timeFormatter.string(from: session.startedAt)
            for entry in session.entries.sorted(by: { $0.order < $1.order }) {
                let weight = WeightFormat.number(unit.display(fromLb: entry.weightLb))
                var warmNumber = 0
                var workNumber = 0
                for set in entry.sets.sorted(by: { $0.order < $1.order }) {
                    let number: Int
                    if set.isWarmup { warmNumber += 1; number = warmNumber } else { workNumber += 1; number = workNumber }
                    let reps = entry.kind == .reps ? String(set.value) : ""
                    let duration = entry.kind == .timed ? String(set.value) : ""
                    let row = [date, time, session.workoutName, entry.exerciseName,
                               set.isWarmup ? "warmup" : "working", String(number),
                               reps, duration, weight, unit.rawValue]
                    lines.append(row.map(escape).joined(separator: ","))
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}

public enum ExportFileName {
    public static func make(date: Date, ext: String, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return "bh-ai-workout-\(f.string(from: date)).\(ext)"
    }
}
