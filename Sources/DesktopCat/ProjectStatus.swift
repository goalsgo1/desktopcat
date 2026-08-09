import Foundation

/// Cosmetic status color for a project's cat. Purely visual — doesn't affect
/// behavior/movement, just tells you at a glance what kind of attention (if any)
/// a project needs right now.
enum CatStatus: String, CaseIterable {
    case white   // 애매/미정 — status not yet triaged, or genuinely unclear whether to proceed
    case red     // 정지 — stalled with an unresolved next-action question, nobody's moving it
    case yellow  // 대기중 — blocked on someone/something external (review, approval, verification); nothing to actively do but wait
    case blue    // 진행중 — active work, needs continued hands-on effort from us
    case green   // 자동가동 — fully hands-off, runs on its own schedule (e.g. launchd) without intervention
    case purple  // 완료/유지보수 — shipped and stable, no active roadmap, only gets touched if a bug surfaces

    var emoji: String {
        switch self {
        case .white: return "⚪"
        case .red: return "🔴"
        case .yellow: return "🟡"
        case .blue: return "🔵"
        case .green: return "🟢"
        case .purple: return "🟣"
        }
    }

    var label: String {
        switch self {
        case .white: return "애매/미정"
        case .red: return "정지"
        case .yellow: return "대기중"
        case .blue: return "진행중"
        case .green: return "자동가동"
        case .purple: return "완료/유지보수"
        }
    }
}

/// Tracks each roster project's `CatStatus`, one "name=color" line per row in
/// ~/.desktopcat/status.txt, same editable-without-recompiling pattern as
/// ProjectRoster. A name absent from the file (or an unrecognized color) defaults
/// to `.white`.
enum ProjectStatus {
    static let fileURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".desktopcat", isDirectory: true)
            .appendingPathComponent("status.txt")
    }()

    // Shown on first launch before the user has set up their own roster.
    private static let defaultStatuses: [String: CatStatus] = [
        "Project One": .blue,
        "Project Two": .white,
    ]

    static func load() -> [String: CatStatus] {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            save(defaultStatuses)
            return defaultStatuses
        }
        guard let data = try? Data(contentsOf: fileURL), let text = String(data: data, encoding: .utf8) else {
            return defaultStatuses
        }
        var result: [String: CatStatus] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, let status = CatStatus(rawValue: parts[1].trimmingCharacters(in: .whitespaces)) else { continue }
            result[name] = status
        }
        return result
    }

    static func save(_ statuses: [String: CatStatus]) {
        let fm = FileManager.default
        let dir = fileURL.deletingLastPathComponent()
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let content = statuses.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.rawValue)" }
            .joined(separator: "\n")
        try? (content + (content.isEmpty ? "" : "\n")).write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
