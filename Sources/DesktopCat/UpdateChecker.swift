import Foundation

/// Talks to the GitHub Releases API for goalsgo1/desktopcat — no Sparkle/appcast
/// infrastructure, just the same "latest release" endpoint used to verify builds.
enum UpdateChecker {
    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/goalsgo1/desktopcat/releases/latest")!

    struct ReleaseInfo {
        let version: String // e.g. "1.0.3" (tag_name with the leading "v" stripped)
        let downloadURL: URL
    }

    enum CheckError: LocalizedError {
        case network(Error)
        case badResponse
        case noZipAsset

        var errorDescription: String? {
            switch self {
            case .network(let error): return "네트워크 오류: \(error.localizedDescription)"
            case .badResponse: return "GitHub 응답을 읽을 수 없습니다."
            case .noZipAsset: return "릴리즈에서 zip 파일을 찾을 수 없습니다."
            }
        }
    }

    static func fetchLatest(completion: @escaping (Result<ReleaseInfo, CheckError>) -> Void) {
        let task = URLSession.shared.dataTask(with: latestReleaseAPI) { data, _, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(.network(error))) }
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let assets = json["assets"] as? [[String: Any]] else {
                DispatchQueue.main.async { completion(.failure(.badResponse)) }
                return
            }
            let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            guard let zipAsset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".zip") == true }),
                  let urlString = zipAsset["browser_download_url"] as? String,
                  let url = URL(string: urlString) else {
                DispatchQueue.main.async { completion(.failure(.noZipAsset)) }
                return
            }
            DispatchQueue.main.async { completion(.success(ReleaseInfo(version: version, downloadURL: url))) }
        }
        task.resume()
    }

    /// Numeric per-component comparison so "1.0.10" correctly beats "1.0.9"
    /// (plain string comparison would get that backwards).
    static func isNewer(_ a: String, than b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(aParts.count, bParts.count) {
            let x = i < aParts.count ? aParts[i] : 0
            let y = i < bParts.count ? bParts[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    static func currentVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}
