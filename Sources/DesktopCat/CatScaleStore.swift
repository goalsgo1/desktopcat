import Foundation

/// Persists the chosen cat sprite scale (0.5x / 1x / 1.5x / 2x) across restarts,
/// same one-file-per-setting pattern as ProjectStatus/LatestVersionStore.
enum CatScaleStore {
    static let fileURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".desktopcat", isDirectory: true)
            .appendingPathComponent("scale.txt")
    }()

    static let allowedScales: [CGFloat] = [0.5, 1.0, 1.5, 2.0]
    static let defaultScale: CGFloat = 1.0

    static func load() -> CGFloat {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8),
              let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              allowedScales.contains(CGFloat(value)) else {
            return defaultScale
        }
        return CGFloat(value)
    }

    static func save(_ scale: CGFloat) {
        let fm = FileManager.default
        let dir = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try? "\(scale)".write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
