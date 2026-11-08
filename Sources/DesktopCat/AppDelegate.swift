import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Each cat is its own NSWindow driven by a 30fps Timer, so an unbounded
    /// roster could quietly tank performance. 100 is far beyond any real
    /// project count and still lays out cleanly with the column-wrapping
    /// left-alignment layout, so it's a safety net rather than a real limit.
    private let maxCatCount = 200

    private var roster: [String] = []
    private var projectStatuses: [String: CatStatus] = [:]
    private var catWindows: [CatWindow] = []
    private var catScale: CGFloat = CatScaleStore.defaultScale
    private var statusItem: NSStatusItem!
    private var settingsPanel: SettingsPanel!
    private var catSelectionPanel: CatSelectionPanel!
    private var summaryEditPanel: SummaryEditPanel!
    private var midnightCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        summaryEditPanel = SummaryEditPanel(onSave: { [weak self] oldName, newName, text in
            self?.saveSummaryEdit(oldName: oldName, newName: newName, text: text)
        })
        roster = ProjectRoster.load()
        if roster.count > maxCatCount {
            roster = Array(roster.prefix(maxCatCount))
            ProjectRoster.save(roster)
        }
        projectStatuses = ProjectStatus.load()
        catScale = CatScaleStore.load()
        roster.forEach { _ = ProjectSummaries.summary(for: $0) } // pre-create summary files so they're editable right away
        CatWindow.tickIntervalValue = roster.count > 100 ? 1.0 / 10.0 : (roster.count > 60 ? 1.0 / 20.0 : 1.0 / 30.0)
        let positions = spawnPositions(count: roster.count)

        catWindows = zip(roster, positions).map { name, position in
            let cat = CatWindow(label: name, initialPosition: position, status: projectStatuses[name] ?? .white, scale: catScale)
            cat.startRoaming()
            return cat
        }

        settingsPanel = SettingsPanel(
            catCount: catWindows.count,
            projects: roster,
            projectStatuses: projectStatuses,
            catScale: catScale,
            onAdd: { [weak self] name in self?.addProject(name) },
            onRemove: { [weak self] name in self?.removeProject(name) },
            onToggleAligned: { [weak self] enabled in self?.applyAlignment(enabled: enabled) },
            onShowCatList: { [weak self] in self?.catSelectionPanel.toggle() },
            onEditSummary: { [weak self] name in self?.summaryEditPanel.open(for: name) },
            onToggleSendToBack: { [weak self] enabled in self?.applySendToBack(enabled: enabled) },
            onStatusChange: { [weak self] name, status in self?.setStatus(name: name, status: status) },
            onCatScaleChange: { [weak self] scale in self?.applyCatScale(scale) },
            onUninstall: { [weak self] in self?.performUninstall() },
            onCheckForUpdates: { [weak self] in self?.checkForUpdates() },
            onRestart: { [weak self] in self?.performRestart() }
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

        let cached = LatestVersionStore.load()
        settingsPanel.updateLatestVersion(cached?.version)
        if cached == nil || cached?.checkedDay != LatestVersionStore.todayString() {
            performDailyVersionCheck() // never checked, or last check was a previous calendar day
        }
        scheduleNextMidnightCheck()
    }

    /// Without this, AppKit quits the whole app the moment the last visible
    /// window closes (e.g. removing the only remaining cat) — this is a
    /// menu-bar-driven background app, so closing windows should never quit it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func addProject(_ name: String) {
        guard !roster.contains(name) else { return }
        guard roster.count < maxCatCount else {
            showAlert(title: "고양이가 너무 많습니다", message: "최대 \(maxCatCount)마리까지만 추가할 수 있습니다.")
            return
        }
        roster.append(name)
        ProjectRoster.save(roster)
        _ = ProjectSummaries.summary(for: name) // pre-create its summary file

        let position = spawnPositions(count: 1).first ?? .zero
        let cat = CatWindow(label: name, initialPosition: position, scale: catScale)
        cat.applyWindowLevel()
        cat.startRoaming()
        catWindows.append(cat)

        refreshUI()
    }

    private func removeProject(_ name: String) {
        guard let rosterIndex = roster.firstIndex(of: name) else { return }
        roster.remove(at: rosterIndex)
        ProjectRoster.save(roster)

        if projectStatuses.removeValue(forKey: name) != nil {
            ProjectStatus.save(projectStatuses)
        }

        if let catIndex = catWindows.firstIndex(where: { $0.name == name }) {
            catWindows[catIndex].close()
            catWindows.remove(at: catIndex)
        }

        refreshUI()
    }

    /// Changes a project's fur color from the settings panel picker, persisting
    /// the choice so it survives app restarts.
    private func setStatus(name: String, status: CatStatus) {
        projectStatuses[name] = status
        ProjectStatus.save(projectStatuses)
        catWindows.first(where: { $0.name == name })?.setStatus(status)
        refreshUI()
    }

    /// Saves the edited summary text, renaming the project first if the name
    /// field changed — updates the roster, the cat's on-screen label, any
    /// roamingExceptions membership, and the summary file's name, all together.
    private func saveSummaryEdit(oldName: String, newName: String, text: String) {
        guard newName != oldName else {
            ProjectSummaries.write(text, for: oldName)
            return
        }
        guard !roster.contains(newName) else {
            showAlert(title: "이름 변경 실패", message: "\"\(newName)\" 프로젝트가 이미 있습니다.")
            return
        }

        if let idx = roster.firstIndex(of: oldName) {
            roster[idx] = newName
            ProjectRoster.save(roster)
        }
        if let cat = catWindows.first(where: { $0.name == oldName }) {
            cat.rename(to: newName)
        }
        if AppSettings.shared.roamingExceptions.remove(oldName) != nil {
            AppSettings.shared.roamingExceptions.insert(newName)
        }
        if let status = projectStatuses.removeValue(forKey: oldName) {
            projectStatuses[newName] = status
            ProjectStatus.save(projectStatuses)
        }
        ProjectSummaries.rename(oldName, to: newName)
        ProjectSummaries.write(text, for: newName)
        refreshUI()
    }

    private func refreshUI() {
        statusItem.button?.title = "🐱×\(catWindows.count)"
        settingsPanel.updateProjects(roster, projectStatuses: projectStatuses, catCount: catWindows.count)
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

    /// Changes every cat's sprite size (0.5x/1x/1.5x/2x). CatWindow bakes
    /// spriteSize/windowWidth into its layout at init time, so an in-place resize
    /// isn't practical — instead every window is closed and a fresh one spawned
    /// at the exact same position, name, and status color. If "왼쪽 정렬" is on,
    /// the line-up is recomputed afterward so row/column spacing matches the new size.
    private func applyCatScale(_ scale: CGFloat) {
        guard scale != catScale else { return }
        catScale = scale
        CatScaleStore.save(scale)

        catWindows = catWindows.map { old in
            let cat = CatWindow(label: old.name, initialPosition: old.currentPosition,
                                 status: projectStatuses[old.name] ?? .white, scale: scale)
            cat.applyWindowLevel()
            old.close()
            cat.startRoaming()
            return cat
        }

        if AppSettings.shared.alignedEnabled {
            applyAlignment(enabled: true) // recompute the line-up for the new size
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

    /// Slots along the left edge of the multi-monitor bounds, filled top-to-bottom
    /// in a column and wrapping into a new column further right once a column runs
    /// out of vertical room. Row count per column is derived from actual screen
    /// height (not a fixed number), so it adapts to whatever display is in use and
    /// never overflows off-screen no matter how many cats are lined up. Row/column
    /// spacing scales with catScale so bigger sprites don't overlap when lined up.
    ///
    /// Uses `visibleFrame` (not `frame`) so the column sits entirely above the Dock
    /// and below the menu bar — `frame` covers the whole physical screen including
    /// the strip the Dock occupies, which is what let the bottom rows get hidden
    /// behind it. Top/bottom margins scale with the sprite so the label strip below
    /// each cat (which extends further past `position.y` at bigger sizes) also
    /// always clears the Dock, and the last row is hard-clamped to the safe line as
    /// a backstop against the row-count math's usual one-row rounding overshoot.
    private func alignmentSlots(count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        let bounds = NSScreen.screens.reduce(CGRect.null) { $0.union($1.visibleFrame) }
        let marginX: CGFloat = 120
        let columnSpacing: CGFloat = 130 * catScale
        let rowSpacing: CGFloat = 90 * catScale
        let spriteHalf = CatWindow.spriteSize(forScale: catScale) / 2
        let topMargin: CGFloat = 20 + spriteHalf
        let bottomMargin: CGFloat = 20 + spriteHalf + CatWindow.labelHeight
        let usableHeight = max(bounds.height - topMargin - bottomMargin, rowSpacing)
        let rowsPerColumn = max(1, Int(usableHeight / rowSpacing) + 1)
        let startY = bounds.maxY - topMargin
        let minSafeY = bounds.minY + bottomMargin

        return (0..<count).map { i in
            let column = i / rowsPerColumn
            let row = i % rowsPerColumn
            let x = bounds.minX + marginX + CGFloat(column) * columnSpacing
            let y = max(startY - CGFloat(row) * rowSpacing, minSafeY)
            return CGPoint(x: x, y: y)
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

    /// Returns nil if it's safe to modify/replace the running .app bundle in place,
    /// or a user-facing explanation if not: either this is a raw dev binary (no
    /// .app bundle at all), or macOS's App Translocation is sandboxing a
    /// freshly-downloaded-but-not-yet-moved app into a random read-only temp
    /// folder (its path contains "/AppTranslocation/../d/...") — writes there
    /// always fail, which is exactly the "couldn't be moved to 'd'" error seen
    /// when a user launches straight out of ~/Downloads instead of Applications.
    private func selfModifyBlockReason() -> String? {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else {
            return "정식 설치된 .app에서 실행 중일 때만 이 기능을 쓸 수 있습니다."
        }
        if bundleURL.path.contains("/AppTranslocation/") {
            return "다운로드 폴더에서 바로 실행하면 macOS가 앱을 임시 읽기 전용 위치에서 실행시켜서 "
                + "이 기능을 쓸 수 없습니다.\nFinder에서 DesktopCat.app을 Applications 폴더로 옮긴 뒤 "
                + "거기서 다시 실행해주세요."
        }
        return nil
    }

    /// Relaunches the app: opens a fresh instance via /usr/bin/open (an
    /// independent process, same trick installUpdate uses to dodge NSWorkspace's
    /// dedup-by-bundle-ID against the still-running instance) then quits this one.
    private func performRestart() {
        let openTask = Process()
        openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        // -n forces a brand-new instance. Without it, `open` on an app that's
        // already running just re-activates that same (soon-to-be-terminated)
        // process instead of spawning a fresh one — so the app quits and never
        // comes back, since the old instance is still alive at this point.
        openTask.arguments = ["-n", Bundle.main.bundleURL.path]
        do {
            try openTask.run()
            NSApp.terminate(nil)
        } catch {
            showAlert(title: "재시작 실패", message: error.localizedDescription)
        }
    }

    /// Moves ~/.desktopcat and the running .app bundle to the Trash, then quits.
    private func performUninstall() {
        if let reason = selfModifyBlockReason() {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "삭제할 수 없음"
            alert.informativeText = reason
            alert.runModal()
            return
        }
        let bundleURL = Bundle.main.bundleURL

        let fm = FileManager.default
        let configDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".desktopcat")
        try? fm.trashItem(at: configDir, resultingItemURL: nil)
        try? fm.trashItem(at: bundleURL, resultingItemURL: nil)
        NSApp.terminate(nil)
    }

    // MARK: - Daily version check (background, silent — just updates the label)

    /// Schedules a one-shot timer for the next local midnight, which performs
    /// the check and then reschedules itself for the following midnight.
    /// Recomputing the delay each time (instead of a fixed 24h repeat) keeps
    /// this correct across DST transitions.
    private func scheduleNextMidnightCheck() {
        midnightCheckTimer?.invalidate()
        let calendar = Calendar.current
        let now = Date()
        guard let nextMidnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0),
                                                     matchingPolicy: .nextTime) else { return }
        let delay = nextMidnight.timeIntervalSince(now)
        midnightCheckTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.performDailyVersionCheck()
            self?.scheduleNextMidnightCheck()
        }
    }

    /// Silent background check — just caches+displays the latest release version.
    /// Never shows an alert or an install prompt; that's what the "업데이트 확인"
    /// button (checkForUpdates) is for.
    private func performDailyVersionCheck() {
        UpdateChecker.fetchLatest { [weak self] result in
            guard let self, case .success(let release) = result else { return }
            LatestVersionStore.save(version: release.version, checkedDay: LatestVersionStore.todayString())
            self.settingsPanel.updateLatestVersion(release.version)
        }
    }

    // MARK: - Update checking

    private func checkForUpdates() {
        UpdateChecker.fetchLatest { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.showAlert(title: "업데이트 확인 실패", message: error.localizedDescription)
            case .success(let release):
                let current = UpdateChecker.currentVersion()
                if UpdateChecker.isNewer(release.version, than: current) {
                    self.promptInstall(release)
                } else {
                    self.showAlert(title: "최신 버전입니다", message: "현재 v\(current) — 최신 버전을 사용 중입니다.")
                }
            }
        }
    }

    private func promptInstall(_ release: UpdateChecker.ReleaseInfo) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "새 버전 v\(release.version)이 있습니다"
        alert.informativeText = "지금 다운로드해서 업데이트할까요? 앱이 자동으로 재시작됩니다."
        alert.addButton(withTitle: "업데이트")
        alert.addButton(withTitle: "나중에")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        installUpdate(from: release.downloadURL)
    }

    /// Downloads the release zip, unzips it, and only *after* confirming a valid
    /// DesktopCat.app is inside does it touch the currently installed copy —
    /// trashing the old one (recoverable) and moving the new one into its place —
    /// then relaunches and quits. Any failure before that point leaves the
    /// running app completely untouched.
    private func installUpdate(from url: URL) {
        if let reason = selfModifyBlockReason() {
            showAlert(title: "업데이트 불가", message: reason)
            return
        }
        let bundleURL = Bundle.main.bundleURL

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempFile, _, error in
            guard let self else { return }
            guard let tempFile else {
                DispatchQueue.main.async {
                    self.showAlert(title: "다운로드 실패", message: error?.localizedDescription ?? "알 수 없는 오류")
                }
                return
            }

            do {
                let fm = FileManager.default
                let workDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
                let zipDest = workDir.appendingPathComponent("update.zip")
                try fm.moveItem(at: tempFile, to: zipDest)

                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                process.arguments = ["-q", "-o", zipDest.path, "-d", workDir.path]
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    throw NSError(domain: "DesktopCatUpdate", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "압축 해제 실패"])
                }

                let newAppURL = workDir.appendingPathComponent("DesktopCat.app")
                guard fm.fileExists(atPath: newAppURL.path) else {
                    throw NSError(domain: "DesktopCatUpdate", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "다운로드한 파일에서 DesktopCat.app을 찾을 수 없습니다."])
                }

                // replaceItemAt is built for exactly this "swap old for new" case — atomic,
                // and doesn't choke if the destination already exists (unlike a plain
                // trashItem-then-moveItem pair, where a failed/skipped trash silently left
                // the old .app in place and made the follow-up move fail as "already exists").
                _ = try fm.replaceItemAt(bundleURL, withItemAt: newAppURL)

                DispatchQueue.main.async {
                    // NSWorkspace's launch APIs dedupe against the *current* (still-running)
                    // process by bundle ID, so asking them to relaunch ourselves just
                    // re-activates the instance that's about to quit instead of starting a
                    // fresh one. Shelling out to /usr/bin/open as an independent process
                    // sidesteps that self-relaunch problem — same trick Sparkle-style
                    // updaters use. Still needs -n, though: plain `open` on an app that's
                    // already running just re-activates it too (same dedup symptom, different
                    // layer) instead of spawning a second process — and since this old
                    // instance is still alive at this exact moment, that would mean
                    // "activate the instance we're about to kill", i.e. it quits and never
                    // comes back.
                    let openTask = Process()
                    openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    openTask.arguments = ["-n", bundleURL.path]
                    do {
                        try openTask.run()
                        NSApp.terminate(nil)
                    } catch {
                        self.showAlert(title: "업데이트는 됐지만 재시작 실패",
                                        message: "새 버전 설치는 완료됐습니다. 직접 다시 실행해주세요.\n(\(error.localizedDescription))")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "업데이트 실패", message: error.localizedDescription)
                }
            }
        }
        task.resume()
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
