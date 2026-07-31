import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var roster: [String] = []
    private var catWindows: [CatWindow] = []
    private var statusItem: NSStatusItem!
    private var settingsPanel: SettingsPanel!
    private var catSelectionPanel: CatSelectionPanel!
    private var summaryEditPanel: SummaryEditPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        summaryEditPanel = SummaryEditPanel()
        roster = ProjectRoster.load()
        roster.forEach { _ = ProjectSummaries.summary(for: $0) } // pre-create summary files so they're editable right away
        let positions = spawnPositions(count: roster.count)

        catWindows = zip(roster, positions).map { name, position in
            let cat = CatWindow(label: name, initialPosition: position)
            cat.startRoaming()
            return cat
        }

        settingsPanel = SettingsPanel(
            catCount: catWindows.count,
            projects: roster,
            onAdd: { [weak self] name in self?.addProject(name) },
            onRemove: { [weak self] name in self?.removeProject(name) },
            onToggleAligned: { [weak self] enabled in self?.applyAlignment(enabled: enabled) },
            onShowCatList: { [weak self] in self?.catSelectionPanel.toggle() },
            onEditSummary: { [weak self] name in self?.summaryEditPanel.open(for: name) },
            onToggleSendToBack: { [weak self] enabled in self?.applySendToBack(enabled: enabled) }
        )

        catSelectionPanel = CatSelectionPanel(
            projects: roster,
            onChange: { [weak self] name, isFree in self?.setRoamingException(name: name, free: isFree) }
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🐱×\(catWindows.count)"
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    /// Without this, AppKit quits the whole app the moment the last visible
    /// window closes (e.g. removing the only remaining cat) — this is a
    /// menu-bar-driven background app, so closing windows should never quit it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func addProject(_ name: String) {
        guard !roster.contains(name) else { return }
        roster.append(name)
        ProjectRoster.save(roster)
        _ = ProjectSummaries.summary(for: name) // pre-create its summary file

        let position = spawnPositions(count: 1).first ?? .zero
        let cat = CatWindow(label: name, initialPosition: position)
        cat.applyWindowLevel()
        cat.startRoaming()
        catWindows.append(cat)

        refreshUI()
    }

    private func removeProject(_ name: String) {
        guard let rosterIndex = roster.firstIndex(of: name) else { return }
        roster.remove(at: rosterIndex)
        ProjectRoster.save(roster)

        if let catIndex = catWindows.firstIndex(where: { $0.name == name }) {
            catWindows[catIndex].close()
            catWindows.remove(at: catIndex)
        }

        refreshUI()
    }

    private func refreshUI() {
        statusItem.button?.title = "🐱×\(catWindows.count)"
        settingsPanel.updateProjects(roster, catCount: catWindows.count)
        catSelectionPanel.updateProjects(roster)
        if AppSettings.shared.alignedEnabled {
            applyAlignment(enabled: true) // reflow the line-up so it stays gap-free after add/remove
        }
    }

    /// Marks a project as free to roam (checked in the "목록 보기" list) or back to
    /// joining the aligned line-up (unchecked). Only matters while alignedEnabled.
    private func setRoamingException(name: String, free: Bool) {
        if free {
            AppSettings.shared.roamingExceptions.insert(name)
        } else {
            AppSettings.shared.roamingExceptions.remove(name)
        }
        if AppSettings.shared.alignedEnabled {
            applyAlignment(enabled: true) // recompute the line-up excluding the now-free cat
        }
    }

    /// Turns "왼쪽 정렬" mode on (walks every non-exempt cat to a fixed slot on the left
    /// edge and holds it there) or off (releases everyone back to normal behavior).
    /// Cats checked in the "목록 보기" list (roamingExceptions) are skipped entirely and
    /// keep wandering/chasing freely.
    private func applyAlignment(enabled: Bool) {
        AppSettings.shared.alignedEnabled = enabled
        if enabled {
            let lineUpCats = catWindows.filter { !AppSettings.shared.roamingExceptions.contains($0.name) }
            let freeCats = catWindows.filter { AppSettings.shared.roamingExceptions.contains($0.name) }
            let slots = alignmentSlots(count: lineUpCats.count)
            for (cat, slot) in zip(lineUpCats, slots) {
                cat.setAlignedTarget(slot)
            }
            freeCats.forEach { $0.setAlignedTarget(nil) }
        } else {
            catWindows.forEach { $0.setAlignedTarget(nil) }
        }
    }

    /// Toggles "화면 맨 뒤로 이동": drops every cat behind normal app windows
    /// (desktop-icon level) so they stop blocking clicks on whatever's underneath,
    /// or restores the usual always-on-top floating level.
    private func applySendToBack(enabled: Bool) {
        AppSettings.shared.sendToBackEnabled = enabled
        catWindows.forEach { $0.applyWindowLevel() }
    }

    /// Vertically stacked slots along the left edge of the multi-monitor bounds,
    /// centered on screen middle height.
    private func alignmentSlots(count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        let bounds = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let marginX: CGFloat = 120
        let spacing: CGFloat = 90
        let totalHeight = CGFloat(count - 1) * spacing
        let startY = bounds.midY + totalHeight / 2
        return (0..<count).map { i in
            CGPoint(x: bounds.minX + marginX, y: startY - CGFloat(i) * spacing)
        }
    }

    /// Left click toggles the settings panel; right click shows a quick quit menu.
    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showQuitMenu()
        } else {
            settingsPanel.toggle()
        }
    }

    private func showQuitMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit Desktop Cat", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    /// Spreads initial cat positions evenly across the full multi-monitor desktop
    /// (with a little vertical jitter) so they don't all spawn stacked on each other.
    private func spawnPositions(count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        let bounds = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        let margin: CGFloat = 150
        let usableWidth = max(bounds.width - margin * 2, 100)

        return (0..<count).map { i in
            let t: CGFloat = count == 1 ? 0.5 : CGFloat(i) / CGFloat(count - 1)
            let x = bounds.minX + margin + usableWidth * t
            let y = bounds.midY + CGFloat.random(in: -100...100)
            return CGPoint(x: x, y: y)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
