import Foundation

/// Per-project progress summaries shown when a cat is clicked.
/// Stored as one text file per project under ~/.desktopcat/summaries/<name>.txt
/// so they can be edited without recompiling.
enum ProjectSummaries {
    static let directoryURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".desktopcat", isDirectory: true)
            .appendingPathComponent("summaries", isDirectory: true)
    }()

    // Shown once per project the first time its summary file is created.
    private static let defaults: [String: String] = [
        "Project One": """
        Edit this file to describe what's going on with this project.
        ~/.desktopcat/summaries/Project One.txt
        """,
        "Project Two": """
        Each cat reads its own text file, so every project can have its
        own up-to-date status — no restart needed after you edit it.
        """,
    ]

    static func summary(for projectName: String) -> String {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryURL.path) {
            try? fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let fileURL = directoryURL.appendingPathComponent("\(projectName).txt")
        if !fm.fileExists(atPath: fileURL.path) {
            let seed = defaults[projectName] ?? "진행상황 요약이 아직 없음.\n이 파일을 직접 채워보세요: \(fileURL.path)"
            try? seed.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        guard let data = try? Data(contentsOf: fileURL), let text = String(data: data, encoding: .utf8) else {
            return defaults[projectName] ?? "진행상황 요약을 불러오지 못했습니다."
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "진행상황 요약이 비어 있습니다: \(fileURL.path)" : trimmed
    }

    static func write(_ text: String, for projectName: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryURL.path) {
            try? fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        let fileURL = directoryURL.appendingPathComponent("\(projectName).txt")
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Moves <oldName>.txt to <newName>.txt, if the old file exists.
    static func rename(_ oldName: String, to newName: String) {
        guard oldName != newName else { return }
        let oldURL = directoryURL.appendingPathComponent("\(oldName).txt")
        let newURL = directoryURL.appendingPathComponent("\(newName).txt")
        try? FileManager.default.removeItem(at: newURL) // clear any stale file at the destination first
        try? FileManager.default.moveItem(at: oldURL, to: newURL)
    }
}
