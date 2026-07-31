import AppKit

/// Opened from the "편집" button next to a project in the settings panel's list.
/// Edits the project's name and its ~/.desktopcat/summaries/<project>.txt content
/// together — renaming here updates the roster, the cat's label, and the
/// summary file's name all at once via onSave.
final class SummaryEditPanel: NSObject {
    private let window: NSWindow
    private let nameField: NSTextField
    private let textView: NSTextView
    private var currentProject: String?
    private let onSave: (_ oldName: String, _ newName: String, _ text: String) -> Void

    init(onSave: @escaping (_ oldName: String, _ newName: String, _ text: String) -> Void) {
        self.onSave = onSave

        let width: CGFloat = 380
        let height: CGFloat = 348

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                           styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "진행상황 편집"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.minSize = NSSize(width: 300, height: 220)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.autoresizesSubviews = true

        let name = NSTextField(string: "")
        name.frame = NSRect(x: 16, y: 308, width: width - 32, height: 24)
        name.placeholderString = "프로젝트 이름"
        name.autoresizingMask = [.width, .minYMargin]
        container.addSubview(name)
        nameField = name

        let scrollView = NSScrollView(frame: NSRect(x: 16, y: 52, width: width - 32, height: 246))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let editor = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        editor.isEditable = true
        editor.isRichText = false
        editor.font = .systemFont(ofSize: 12)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 6, height: 8)
        scrollView.documentView = editor
        textView = editor

        container.addSubview(scrollView)

        let cancelButton = NSButton(title: "취소", target: nil, action: nil)
        cancelButton.frame = NSRect(x: width - 176, y: 16, width: 76, height: 28)
        cancelButton.bezelStyle = .rounded
        cancelButton.autoresizingMask = [.minXMargin]
        container.addSubview(cancelButton)

        let saveButton = NSButton(title: "저장", target: nil, action: nil)
        saveButton.frame = NSRect(x: width - 92, y: 16, width: 76, height: 28)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.autoresizingMask = [.minXMargin]
        container.addSubview(saveButton)

        window.contentView = container

        super.init()

        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        saveButton.target = self
        saveButton.action = #selector(saveTapped)
    }

    func open(for projectName: String) {
        currentProject = projectName
        window.title = "\(projectName) — 진행상황 편집"
        nameField.stringValue = projectName
        textView.string = ProjectSummaries.summary(for: projectName)
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func saveTapped() {
        guard let oldName = currentProject else { return }
        let newName = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        onSave(oldName, newName, textView.string)
        window.orderOut(nil)
    }

    @objc private func cancelTapped() {
        window.orderOut(nil)
    }
}
