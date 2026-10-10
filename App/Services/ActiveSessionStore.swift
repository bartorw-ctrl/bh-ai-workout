import Foundation
import Core

/// Saves the in-progress workout to a file after every change so it can be restored if the app is killed (SPEC 5.12).
enum ActiveSessionStore {
    private static var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("active-session.json")
    }

    static func load() -> ActiveSession? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ActiveSession.self, from: data)
    }

    static func save(_ session: ActiveSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
