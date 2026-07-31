import AppKit

/// Small panel opened from "목록 보기" while 왼쪽 정렬 is on: a checkbox per cat.
/// Checked cats stay free to roam/chase instead of joining the aligned line-up.
final class CatSelectionPanel: NSObject {
    private let window: NSWindow
    private let scrollView: NSScrollView
    private let container = NSView()
    private var checkboxes: [NSButton] = []
    private var projects: [String]
    private let onChange: (String, Bool) -> Void

    private let rowHeight: CGFloat = 28
    private let width: CGFloat = 280
    private let maxVisibleRows: CGFloat = 8
    private let minHeight: CGFloat = 60

    init(projects: [String], onChange: @escaping (String, Bool) -> Void) {
        self.projects = projects
        self.onChange = onChange

        let height = CatSelectionPanel.visibleHeight(for: projects.count, rowHeight: rowHeight,
                                                       maxVisibleRows: maxVisibleRows, minHeight: minHeight)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                           styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "자유롭게 돌아다닐 고양이"
        window.isReleasedWhenClosed = false
        window.level = .floating

        scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = container
        window.contentView = scrollView

        super.init()

        rebuildCheckboxes()
    }

    private static func visibleHeight(for count: Int, rowHeight: CGFloat, maxVisibleRows: CGFloat, minHeight: CGFloat) -> CGFloat {
        let contentHeight = CGFloat(max(count, 1)) * rowHeight
        return min(max(contentHeight, minHeight), maxVisibleRows * rowHeight)
    }

    private func rebuildCheckboxes() {
        checkboxes.forEach { $0.removeFromSuperview() }
        checkboxes.removeAll()

        let totalHeight = max(CGFloat(projects.count) * rowHeight, 1)
        container.frame = NSRect(x: 0, y: 0, width: width, height: totalHeight)

        for (index, name) in projects.enumerated() {
            let y = totalHeight - CGFloat(index + 1) * rowHeight + 4
            let box = NSButton(checkboxWithTitle: name, target: self, action: #selector(checkboxTapped(_:)))
            box.frame = NSRect(x: 12, y: y, width: width - 24, height: 20)
            box.state = AppSettings.shared.roamingExceptions.contains(name) ? .on : .off
            box.tag = index
            container.addSubview(box)
            checkboxes.append(box)
        }

        // Resize the window/scroll view to fit the current project count exactly
        // (up to the cap), so short lists don't leave empty space above them.
        let fittedHeight = CatSelectionPanel.visibleHeight(for: projects.count, rowHeight: rowHeight,
                                                             maxVisibleRows: maxVisibleRows, minHeight: minHeight)
        window.setContentSize(NSSize(width: width, height: fittedHeight))

        // If the list is taller than the window (scrolling case), start scrolled to the top.
        container.scroll(NSPoint(x: 0, y: totalHeight))
    }

    @objc private func checkboxTapped(_ sender: NSButton) {
        guard sender.tag >= 0 && sender.tag < projects.count else { return }
        onChange(projects[sender.tag], sender.state == .on)
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

    /// Called by AppDelegate whenever the roster changes so the checklist stays current.
    func updateProjects(_ names: [String]) {
        projects = names
        rebuildCheckboxes()
    }
}
