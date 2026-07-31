import AppKit

/// Opened from the "편집" button next to a project in the settings panel's list.
/// Edits ~/.desktopcat/summaries/<project>.txt in place.
final class SummaryEditPanel: NSObject {
    private let window: NSWindow
    private let textView: NSTextView
    private var currentProject: String?

    override init() {
        let width: CGFloat = 380
        let height: CGFloat = 300

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                           styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "진행상황 편집"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.minSize = NSSize(width: 300, height: 200)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.autoresizesSubviews = true

        let scrollView = NSScrollView(frame: NSRect(x: 16, y: 52, width: width - 32, height: height - 68))
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
        textView.string = ProjectSummaries.summary(for: projectName)
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func saveTapped() {
        guard let name = currentProject else { return }
        ProjectSummaries.write(textView.string, for: name)
        window.orderOut(nil)
    }

    @objc private func cancelTapped() {
        window.orderOut(nil)
    }
}
