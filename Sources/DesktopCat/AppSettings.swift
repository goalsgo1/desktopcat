import Foundation

/// Shared runtime toggles, checked by every CatWindow on each tick / click.
final class AppSettings {
    static let shared = AppSettings()
    private init() {}

    var chaseEnabled: Bool = true
    var clickSummaryEnabled: Bool = true
    var alignedEnabled: Bool = false
    var sendToBackEnabled: Bool = false

    /// Project names that stay free to roam even while alignedEnabled is on.
    var roamingExceptions: Set<String> = []
}
