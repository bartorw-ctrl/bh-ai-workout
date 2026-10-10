import Foundation
import SwiftData
import Core

enum ExportFormat: String, Identifiable {
    case csv, json
    var id: String { rawValue }
}

struct ImportResult {
    var workouts: Int
    var sessions: Int
    var exercises: Int
}

/// Export and import of all data (SPEC 9.4–9.7).
enum DataTransferService {
    static func makeExport(context: ModelContext, now: Date = Date()) throws -> ExportFile {
        let sessions = try context.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.startedAt)]))
        let workouts = try context.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.createdAt)]))
        let custom = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isBuiltIn },
                                                                sortBy: [SortDescriptor(\.name)]))
        return ExportFile(exportedAt: now,
                          settings: SettingsDTO(unit: AppSettings.unit, restSeconds: AppSettings.restSeconds),
                          customExercises: custom.map(\.dto),
                          workouts: workouts.map(\.dto),
                          sessions: sessions.map(\.dto))
    }

    /// Writes the export to a temporary file and returns its URL for the share sheet.
    static func writeExport(format: ExportFormat, context: ModelContext) throws -> URL {
        let file = try makeExport(context: context)
        let data: Data
        switch format {
        case .json:
            data = try JSONTransfer.encode(file)
        case .csv:
            data = Data(CSVExport.make(sessions: file.sessions, unit: AppSettings.unit).utf8)
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(ExportFileName.make(date: file.exportedAt, ext: format.rawValue))
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Reads a file picked in the Files app.
    static func read(url: URL) throws -> ExportFile {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: url)
        return try JSONTransfer.decode(data)
    }

    /// Applies an import. Imported sessions are never sent to Apple Health (SPEC 8.5).
    static func apply(file: ExportFile, mode: ImportMode, context: ModelContext) throws -> ImportResult {
        do {
            return try applyUnsaved(file: file, mode: mode, context: context)
        } catch {
            // All-or-nothing: undo any partial changes (SPEC 9.7).
            context.rollback()
            throw error
        }
    }

    private static func applyUnsaved(file: ExportFile, mode: ImportMode, context: ModelContext) throws -> ImportResult {
        if mode == .replace {
            for session in try context.fetch(FetchDescriptor<Session>()) {
                context.delete(session)
            }
            for workout in try context.fetch(FetchDescriptor<Workout>()) {
                context.delete(workout)
            }
            for exercise in try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isBuiltIn })) {
                context.delete(exercise)
            }
        }

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let workouts = try context.fetch(FetchDescriptor<Workout>())
        let sessions = try context.fetch(FetchDescriptor<Session>())
        let plan = ImportPlan.make(file: file, mode: mode,
                                   existingExerciseNames: Set(exercises.map(\.name)),
                                   existingWorkoutIDs: Set(workouts.map(\.id)),
                                   existingSessionIDs: Set(sessions.map(\.id)))

        let builtInNames = Set(exercises.filter(\.isBuiltIn).map { $0.name.lowercased() })
        var addedExercises = 0
        for dto in plan.exercises where !builtInNames.contains(dto.name.lowercased()) {
            context.insert(Exercise(name: dto.name, equipment: dto.equipment, kind: dto.kind, isBuiltIn: false))
            addedExercises += 1
        }
        for dto in plan.workouts {
            Workout.insert(dto, into: context)
        }
        for dto in plan.sessions {
            Session.insert(dto, into: context)
        }
        try context.save()
        return ImportResult(workouts: plan.workouts.count, sessions: plan.sessions.count, exercises: addedExercises)
    }
}
