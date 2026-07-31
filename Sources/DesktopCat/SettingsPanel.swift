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
    private let onAdd: (String) -> Void
    private let onRemove: (String) -> Void
    private let onToggleAligned: (Bool) -> Void
    private let onShowCatList: () -> Void
    private let onEditSummary: (String) -> Void
    private let onToggleSendToBack: (Bool) -> Void
    private let onUninstall: () -> Void
    private let onCheckForUpdates: () -> Void
    private let listButton: NSButton

    init(catCount: Int,
         projects: [String],
         onAdd: @escaping (String) -> Void,
         onRemove: @escaping (String) -> Void,
         onToggleAligned: @escaping (Bool) -> Void,
         onShowCatList: @escaping () -> Void,
         onEditSummary: @escaping (String) -> Void,
         onToggleSendToBack: @escaping (Bool) -> Void,
         onUninstall: @escaping () -> Void,
         onCheckForUpdates: @escaping () -> Void) {
        self.projects = projects
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.onToggleAligned = onToggleAligned
        self.onShowCatList = onShowCatList
        self.onEditSummary = onEditSummary
        self.onToggleSendToBack = onToggleSendToBack
        self.onUninstall = onUninstall
        self.onCheckForUpdates = onCheckForUpdates
        listButton = NSButton(title: "목록 보기", target: nil, action: nil)

        let width: CGFloat = 280
        let height: CGFloat = 456
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        window = NSWindow(contentRect: rect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "DesktopCat 설정"
        window.isReleasedWhenClosed = false
        window.level = .floating

        statusLabel = NSTextField(labelWithString: "고양이 \(catCount)마리 실행 중")
        statusLabel.frame = NSRect(x: 16, y: 420, width: 248, height: 20)
        statusLabel.textColor = .secondaryLabelColor

        let container = NSView(frame: NSRect(origin: .zero, size: rect.size))
        container.addSubview(statusLabel)

        let scrollView = NSScrollView(frame: NSRect(x: 16, y: 300, width: 248, height: 110))
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

        nameField.frame = NSRect(x: 16, y: 266, width: 130, height: 24)
        nameField.placeholderString = "프로젝트 이름"
        container.addSubview(nameField)

        let addButton = NSButton(title: "추가", target: nil, action: nil)
        addButton.frame = NSRect(x: 154, y: 266, width: 50, height: 24)
        addButton.bezelStyle = .rounded
        container.addSubview(addButton)

        let removeButton = NSButton(title: "제거", target: nil, action: nil)
        removeButton.frame = NSRect(x: 210, y: 266, width: 54, height: 24)
        removeButton.bezelStyle = .rounded
        container.addSubview(removeButton)

        let chaseCheckbox = NSButton(checkboxWithTitle: "마우스 추격", target: nil, action: nil)
        chaseCheckbox.frame = NSRect(x: 16, y: 232, width: 248, height: 24)
        chaseCheckbox.state = AppSettings.shared.chaseEnabled ? .on : .off
        container.addSubview(chaseCheckbox)

        let clickCheckbox = NSButton(checkboxWithTitle: "클릭 시 진행상황 요약 보기",
                                      target: nil, action: nil)
        clickCheckbox.frame = NSRect(x: 16, y: 198, width: 248, height: 24)
        clickCheckbox.state = AppSettings.shared.clickSummaryEnabled ? .on : .off
        container.addSubview(clickCheckbox)

        let alignCheckbox = NSButton(checkboxWithTitle: "왼쪽 정렬 (고정)", target: nil, action: nil)
        alignCheckbox.frame = NSRect(x: 16, y: 164, width: 150, height: 24)
        alignCheckbox.state = AppSettings.shared.alignedEnabled ? .on : .off
        container.addSubview(alignCheckbox)

        listButton.frame = NSRect(x: 172, y: 163, width: 92, height: 22)
        listButton.bezelStyle = .rounded
        listButton.controlSize = .small
        listButton.isHidden = !AppSettings.shared.alignedEnabled
        container.addSubview(listButton)

        let sendToBackCheckbox = NSButton(checkboxWithTitle: "화면 맨 뒤로 이동", target: nil, action: nil)
        sendToBackCheckbox.frame = NSRect(x: 16, y: 130, width: 248, height: 24)
        sendToBackCheckbox.state = AppSettings.shared.sendToBackEnabled ? .on : .off
        container.addSubview(sendToBackCheckbox)

        let updateButton = NSButton(title: "업데이트 확인", target: nil, action: nil)
        updateButton.frame = NSRect(x: 16, y: 92, width: 248, height: 28)
        updateButton.bezelStyle = .rounded
        container.addSubview(updateButton)

        let quitButton = NSButton(title: "Quit Desktop Cat", target: nil, action: nil)
        quitButton.frame = NSRect(x: 16, y: 54, width: 248, height: 28)
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

        listButton.target = self
        listButton.action = #selector(showCatList)

        sendToBackCheckbox.target = self
        sendToBackCheckbox.action = #selector(toggleSendToBack(_:))

        updateButton.target = self
        updateButton.action = #selector(checkForUpdatesTapped)

        quitButton.target = self
        quitButton.action = #selector(quit)

        uninstallButton.target = self
        uninstallButton.action = #selector(uninstallTapped)
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

    /// Called by AppDelegate after the roster actually changes (cat spawned/closed).
    func updateProjects(_ names: [String], catCount: Int) {
        projects = names
        statusLabel.stringValue = "고양이 \(catCount)마리 실행 중"
        tableView.reloadData()
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

    @objc private func quit() {
        NSApp.terminate(nil)
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
        label.frame = NSRect(x: 4, y: 2, width: width - 58, height: 18)
        label.lineBreakMode = .byTruncatingTail
        rowView.addSubview(label)

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
