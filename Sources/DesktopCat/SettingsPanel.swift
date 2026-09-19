import AppKit

/// Utility panel toggled from the menu-bar icon: shows the current project
/// roster, lets the user add/remove projects (each spawns/despawns a cat
/// immediately), and toggle chase / click-summary behavior for every cat.
final class SettingsPanel: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private let window: NSWindow
    private let statusLabel: NSTextField
    private let tableView = NSTableView()
    private let nameField = NSTextField()
    private var projects: [String]
    private var projectStatuses: [String: CatStatus]
    private let onAdd: (String) -> Void
    private let onRemove: (String) -> Void
    private let onToggleAligned: (Bool) -> Void
    private let onShowCatList: () -> Void
    private let onEditSummary: (String) -> Void
    private let onToggleSendToBack: (Bool) -> Void
    private let onStatusChange: (String, CatStatus) -> Void
    private let onCatScaleChange: (CGFloat) -> Void
    private let onUninstall: () -> Void
    private let onCheckForUpdates: () -> Void
    private let onRestart: () -> Void
    private let listButton: NSButton
    private let infoPanel = InfoPanel()
    private let latestVersionLabel: NSTextField

    init(catCount: Int,
         projects: [String],
         projectStatuses: [String: CatStatus],
         catScale: CGFloat,
         onAdd: @escaping (String) -> Void,
         onRemove: @escaping (String) -> Void,
         onToggleAligned: @escaping (Bool) -> Void,
         onShowCatList: @escaping () -> Void,
         onEditSummary: @escaping (String) -> Void,
         onToggleSendToBack: @escaping (Bool) -> Void,
         onStatusChange: @escaping (String, CatStatus) -> Void,
         onCatScaleChange: @escaping (CGFloat) -> Void,
         onUninstall: @escaping () -> Void,
         onCheckForUpdates: @escaping () -> Void,
         onRestart: @escaping () -> Void) {
        self.projects = projects
        self.projectStatuses = projectStatuses
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.onToggleAligned = onToggleAligned
        self.onShowCatList = onShowCatList
        self.onEditSummary = onEditSummary
        self.onToggleSendToBack = onToggleSendToBack
        self.onStatusChange = onStatusChange
        self.onCatScaleChange = onCatScaleChange
        self.onUninstall = onUninstall
        self.onCheckForUpdates = onCheckForUpdates
        self.onRestart = onRestart
        listButton = NSButton(title: "목록 보기", target: nil, action: nil)

        let width: CGFloat = 280
        let height: CGFloat = 570
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        window = NSWindow(contentRect: rect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "DesktopCat 설정"
        window.isReleasedWhenClosed = false
        window.level = .floating

        let container = NSView(frame: NSRect(origin: .zero, size: rect.size))

        // First-time users see a grid of unlabeled buttons and colored cats with
        // no context — this is the one thing that explains all of it, so it goes
        // at the very top where it's impossible to miss.
        let infoButton = NSButton(title: "ℹ️ 사용법 보기", target: nil, action: nil)
        infoButton.frame = NSRect(x: 16, y: 534, width: 248, height: 28)
        infoButton.bezelStyle = .rounded
        container.addSubview(infoButton)

        statusLabel = NSTextField(labelWithString: "고양이 \(catCount)마리 실행 중")
        statusLabel.frame = NSRect(x: 16, y: 498, width: 170, height: 20)
        statusLabel.textColor = .secondaryLabelColor
        container.addSubview(statusLabel)

        let versionLabel = NSTextField(labelWithString: "v\(UpdateChecker.currentVersion())")
        versionLabel.frame = NSRect(x: 192, y: 498, width: 72, height: 20)
        versionLabel.alignment = .right
        versionLabel.textColor = .tertiaryLabelColor
        versionLabel.font = .systemFont(ofSize: 11)
        container.addSubview(versionLabel)

        let scrollView = NSScrollView(frame: NSRect(x: 16, y: 378, width: 248, height: 110))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.width = 224
        tableView.frame = NSRect(x: 0, y: 0, width: 248, height: 110)
        tableView.autoresizingMask = [.width]
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 22
        scrollView.documentView = tableView
        container.addSubview(scrollView)

        nameField.frame = NSRect(x: 16, y: 344, width: 130, height: 24)
        nameField.placeholderString = "프로젝트 이름"
        container.addSubview(nameField)

        let addButton = NSButton(title: "추가", target: nil, action: nil)
        addButton.frame = NSRect(x: 154, y: 344, width: 50, height: 24)
        addButton.bezelStyle = .rounded
        container.addSubview(addButton)

        let removeButton = NSButton(title: "제거", target: nil, action: nil)
        removeButton.frame = NSRect(x: 210, y: 344, width: 54, height: 24)
        removeButton.bezelStyle = .rounded
        container.addSubview(removeButton)

        let chaseCheckbox = NSButton(checkboxWithTitle: "마우스 추격", target: nil, action: nil)
        chaseCheckbox.frame = NSRect(x: 16, y: 310, width: 248, height: 24)
        chaseCheckbox.state = AppSettings.shared.chaseEnabled ? .on : .off
        container.addSubview(chaseCheckbox)

        let clickCheckbox = NSButton(checkboxWithTitle: "클릭 시 진행상황 요약 보기",
                                      target: nil, action: nil)
        clickCheckbox.frame = NSRect(x: 16, y: 276, width: 248, height: 24)
        clickCheckbox.state = AppSettings.shared.clickSummaryEnabled ? .on : .off
        container.addSubview(clickCheckbox)

        let alignCheckbox = NSButton(checkboxWithTitle: "왼쪽 정렬 (고정)", target: nil, action: nil)
        alignCheckbox.frame = NSRect(x: 16, y: 242, width: 150, height: 24)
        alignCheckbox.state = AppSettings.shared.alignedEnabled ? .on : .off
        container.addSubview(alignCheckbox)

        listButton.frame = NSRect(x: 172, y: 241, width: 92, height: 22)
        listButton.bezelStyle = .rounded
        listButton.controlSize = .small
        listButton.isHidden = !AppSettings.shared.alignedEnabled
        container.addSubview(listButton)

        let sizeLabel = NSTextField(labelWithString: "고양이 크기")
        sizeLabel.frame = NSRect(x: 16, y: 202, width: 80, height: 24)
        sizeLabel.font = .systemFont(ofSize: 12)
        container.addSubview(sizeLabel)

        let sizeControl = NSSegmentedControl(labels: ["0.5x", "1x", "1.5x", "2x"],
                                              trackingMode: .selectOne, target: nil, action: nil)
        sizeControl.frame = NSRect(x: 100, y: 202, width: 164, height: 24)
        sizeControl.controlSize = .small
        if let index = CatScaleStore.allowedScales.firstIndex(of: catScale) {
            sizeControl.selectedSegment = index
        }
        container.addSubview(sizeControl)

        let sendToBackCheckbox = NSButton(checkboxWithTitle: "화면 맨 뒤로 이동", target: nil, action: nil)
        sendToBackCheckbox.frame = NSRect(x: 16, y: 168, width: 248, height: 24)
        sendToBackCheckbox.state = AppSettings.shared.sendToBackEnabled ? .on : .off
        container.addSubview(sendToBackCheckbox)

        let updateButton = NSButton(title: "업데이트 확인", target: nil, action: nil)
        updateButton.frame = NSRect(x: 16, y: 130, width: 168, height: 28)
        updateButton.bezelStyle = .rounded
        container.addSubview(updateButton)

        // Filled in by AppDelegate from a once-a-day background check (and from
        // the cached value on launch) — not tied to pressing the button above.
        let latest = NSTextField(labelWithString: "최신: -")
        latest.frame = NSRect(x: 190, y: 136, width: 74, height: 16)
        latest.alignment = .right
        latest.font = .systemFont(ofSize: 10)
        latest.textColor = .secondaryLabelColor
        latest.lineBreakMode = .byTruncatingTail
        container.addSubview(latest)
        latestVersionLabel = latest

        let restartButton = NSButton(title: "재시작", target: nil, action: nil)
        restartButton.frame = NSRect(x: 16, y: 54, width: 248, height: 28)
        restartButton.bezelStyle = .rounded
        container.addSubview(restartButton)

        let quitButton = NSButton(title: "Quit Desktop Cat", target: nil, action: nil)
        quitButton.frame = NSRect(x: 16, y: 92, width: 248, height: 28)
        quitButton.bezelStyle = .rounded
        container.addSubview(quitButton)

        let uninstallButton = NSButton(title: "", target: nil, action: nil)
        uninstallButton.attributedTitle = NSAttributedString(
            string: "앱 삭제...",
            attributes: [.foregroundColor: NSColor.systemRed]
        )
        uninstallButton.frame = NSRect(x: 16, y: 16, width: 248, height: 28)
        uninstallButton.bezelStyle = .rounded
        container.addSubview(uninstallButton)

        window.contentView = container

        super.init()

        infoButton.target = self
        infoButton.action = #selector(infoButtonTapped)

        tableView.dataSource = self
        tableView.delegate = self

        nameField.target = self
        nameField.action = #selector(addButtonTapped)

        addButton.target = self
        addButton.action = #selector(addButtonTapped)

        removeButton.target = self
        removeButton.action = #selector(removeButtonTapped)

        chaseCheckbox.target = self
        chaseCheckbox.action = #selector(toggleChase(_:))

        clickCheckbox.target = self
        clickCheckbox.action = #selector(toggleClickSummary(_:))

        alignCheckbox.target = self
        alignCheckbox.action = #selector(toggleAligned(_:))

        sizeControl.target = self
        sizeControl.action = #selector(sizeControlChanged(_:))

        listButton.target = self
        listButton.action = #selector(showCatList)

        sendToBackCheckbox.target = self
        sendToBackCheckbox.action = #selector(toggleSendToBack(_:))

        updateButton.target = self
        updateButton.action = #selector(checkForUpdatesTapped)

        restartButton.target = self
        restartButton.action = #selector(restartTapped)

        quitButton.target = self
        quitButton.action = #selector(quit)

        uninstallButton.target = self
        uninstallButton.action = #selector(uninstallTapped)
    }

    /// Called by AppDelegate after loading the cached value on launch and after
    /// each once-a-day background check. `nil` means no version known yet.
    func updateLatestVersion(_ version: String?) {
        latestVersionLabel.stringValue = "최신: \(version.map { "v\($0)" } ?? "-")"
    }

    func toggle() {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Called by AppDelegate after the roster actually changes (cat spawned/closed)
    /// or after a project's status color is changed.
    func updateProjects(_ names: [String], projectStatuses: [String: CatStatus], catCount: Int) {
        projects = names
        self.projectStatuses = projectStatuses
        statusLabel.stringValue = "고양이 \(catCount)마리 실행 중"
        tableView.reloadData()
    }

    @objc private func infoButtonTapped() {
        infoPanel.toggle()
    }

    @objc private func addButtonTapped() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        onAdd(name)
        nameField.stringValue = ""
    }

    @objc private func removeButtonTapped() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        onRemove(name)
        nameField.stringValue = ""
    }

    @objc private func toggleChase(_ sender: NSButton) {
        AppSettings.shared.chaseEnabled = sender.state == .on
    }

    @objc private func toggleClickSummary(_ sender: NSButton) {
        AppSettings.shared.clickSummaryEnabled = sender.state == .on
    }

    @objc private func toggleAligned(_ sender: NSButton) {
        let enabled = sender.state == .on
        listButton.isHidden = !enabled
        onToggleAligned(enabled)
    }

    @objc private func sizeControlChanged(_ sender: NSSegmentedControl) {
        let scales = CatScaleStore.allowedScales
        guard sender.selectedSegment >= 0 && sender.selectedSegment < scales.count else { return }
        onCatScaleChange(scales[sender.selectedSegment])
    }

    @objc private func showCatList() {
        onShowCatList()
    }

    @objc private func toggleSendToBack(_ sender: NSButton) {
        onToggleSendToBack(sender.state == .on)
    }

    @objc private func checkForUpdatesTapped() {
        onCheckForUpdates()
    }

    @objc private func editButtonTapped(_ sender: NSButton) {
        guard sender.tag >= 0 && sender.tag < projects.count else { return }
        onEditSummary(projects[sender.tag])
    }

    @objc private func statusPopUpChanged(_ sender: NSPopUpButton) {
        guard sender.tag >= 0 && sender.tag < projects.count else { return }
        let statuses = CatStatus.allCases
        guard sender.indexOfSelectedItem >= 0 && sender.indexOfSelectedItem < statuses.count else { return }
        onStatusChange(projects[sender.tag], statuses[sender.indexOfSelectedItem])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func restartTapped() {
        onRestart()
    }

    @objc private func uninstallTapped() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "DesktopCat을 삭제할까요?"
        alert.informativeText = "앱과 설정 파일(~/.desktopcat)을 모두 휴지통으로 보냅니다. "
            + "앱은 즉시 종료됩니다. 휴지통에서 복구할 수 있습니다."
        alert.addButton(withTitle: "취소")
        alert.addButton(withTitle: "삭제")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        onUninstall()
    }

    // MARK: - NSTableViewDataSource / NSTableViewDelegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        projects.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < projects.count else { return nil }
        let name = projects[row]
        let width = tableColumn?.width ?? 224

        let rowView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 22))

        let label = NSTextField(labelWithString: name)
        label.frame = NSRect(x: 4, y: 2, width: width - 106, height: 18)
        label.lineBreakMode = .byTruncatingTail
        rowView.addSubview(label)

        // Status color picker (emoji-only, compact): purely cosmetic (tints the
        // cat's fur) — doesn't change its roaming/chase behavior, just flags its
        // state at a glance. Hover/click shows the full Korean label via the item title.
        let statusPopUp = NSPopUpButton(frame: NSRect(x: width - 100, y: 1, width: 50, height: 20), pullsDown: false)
        statusPopUp.controlSize = .small
        statusPopUp.font = .systemFont(ofSize: 11)
        for catStatus in CatStatus.allCases {
            statusPopUp.addItem(withTitle: catStatus.emoji)
            statusPopUp.lastItem?.toolTip = catStatus.label
        }
        let current = projectStatuses[name] ?? .white
        statusPopUp.selectItem(at: CatStatus.allCases.firstIndex(of: current) ?? 0)
        statusPopUp.target = self
        statusPopUp.action = #selector(statusPopUpChanged(_:))
        statusPopUp.tag = row
        rowView.addSubview(statusPopUp)

        let editButton = NSButton(title: "편집", target: self, action: #selector(editButtonTapped(_:)))
        editButton.frame = NSRect(x: width - 50, y: 0, width: 46, height: 22)
        editButton.bezelStyle = .rounded
        editButton.controlSize = .mini
        editButton.tag = row
        rowView.addSubview(editButton)

        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 && row < projects.count else { return }
        nameField.stringValue = projects[row]
    }
}
