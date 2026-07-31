import Foundation

/// The list of projects to spawn a cat for, one name per line in
/// ~/.desktopcat/projects.txt. Edit that file and restart the app to change
/// the roster; use bin/catproject to append a new entry from the shell.
enum ProjectRoster {
    static let fileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".desktopcat", isDirectory: true)
        return dir.appendingPathComponent("projects.txt")
    }()

    // Shown on first launch before the user has set up their own roster.
    private static let defaultRoster = [
        "Project One",
        "Project Two",
    ]

    static func load() -> [String] {
        let fm = FileManager.default
        let dir = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: fileURL.path) {
            let content = defaultRoster.joined(separator: "\n") + "\n"
            try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        guard let data = try? Data(contentsOf: fileURL), let text = String(data: data, encoding: .utf8) else {
            return defaultRoster
        }
        let names = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return names.isEmpty ? defaultRoster : names
    }

    static func save(_ names: [String]) {
        let content = names.joined(separator: "\n") + "\n"
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
