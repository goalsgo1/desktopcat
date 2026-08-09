import Foundation

/// Caches the most recently seen "latest GitHub release" version number so the
/// settings panel has something to show immediately on launch (before that
/// day's check finishes), and so the daily check can tell whether today has
/// already been checked. One line: "version|yyyy-MM-dd" in local time.
enum LatestVersionStore {
    static let fileURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".desktopcat", isDirectory: true)
            .appendingPathComponent("latest_version.txt")
    }()

    struct Cached {
        let version: String
        let checkedDay: String // yyyy-MM-dd, local calendar day
    }

    static func load() -> Cached? {
        guard let data = try? Data(contentsOf: fileURL), let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "|", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return Cached(version: String(parts[0]), checkedDay: String(parts[1]))
    }

    static func save(version: String, checkedDay: String) {
        let fm = FileManager.default
        let dir = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try? "\(version)|\(checkedDay)".write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Local calendar day as "yyyy-MM-dd", used to decide whether "today" has
    /// already been checked without caring about time-of-day.
    static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
