import AppKit
import CoreGraphics

/// Container view that reports plain clicks back to its owner, so a borderless
/// overlay window can act as a button without adopting a full control hierarchy.
private final class ClickCatchingView: NSView {
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

/// A small, transparent window that carries the cat sprite plus a fixed
/// project-name label, and repositions itself across the full multi-monitor
/// desktop. Each deployed project gets its own independent CatWindow.
/// Clicking a cat shows that project's progress summary.
final class CatWindow {
    private enum State {
        case idle
        case wander
        case chase
    }

    private let window: NSWindow
    private let catView: CatView
    private let labelField: NSTextField
    private var timer: Timer?

    /// Base (1x) sprite size and the name-label strip height below it — exposed
    /// so AppDelegate's alignment math can reserve exactly enough room per cat
    /// (at whatever scale) without duplicating these numbers.
    static let baseSpriteSize: CGFloat = 64
    static let labelHeight: CGFloat = 20
    static func spriteSize(forScale scale: CGFloat) -> CGFloat { baseSpriteSize * scale }

    private let spriteSize: CGFloat
    private let labelHeight: CGFloat = CatWindow.labelHeight
    private let windowWidth: CGFloat

    private let chaseTriggerRadius: CGFloat = 220
    private let chaseGiveUpRadius: CGFloat = 320
    private let restRadius: CGFloat = 42
    private let chaseSpeed: CGFloat = 260   // pt/sec
    private let wanderSpeed: CGFloat = 75   // pt/sec
    private let alignSpeed: CGFloat = 420   // pt/sec — cats hustle to their line-up slot
    private let tickInterval: TimeInterval = 1.0 / 30.0

    private var position: CGPoint
    private var facingLeft = false
    private var state: State = .idle
    private var wanderTarget: CGPoint?
    private var idleUntil: TimeInterval = 0
    private var lastPoseSwapTime: TimeInterval = 0
    private var showTailFlick = false
    private var alignedTarget: CGPoint?
    private var projectName: String
    private var status: CatStatus

    init(label: String, initialPosition: CGPoint, status: CatStatus = .white, scale: CGFloat = 1.0) {
        projectName = label
        self.status = status
        spriteSize = CatWindow.spriteSize(forScale: scale)
        windowWidth = max(180, spriteSize + 56) // keep a comfortable label/margin even at 2x
        position = initialPosition

        let windowHeight = spriteSize + labelHeight
        let rect = NSRect(x: position.x - windowWidth / 2,
                           y: position.y - spriteSize / 2 - labelHeight,
                           width: windowWidth,
                           height: windowHeight)
        window = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false // we hold the only strong reference; avoid AppKit double-releasing on close()
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = CatWindow.windowLevel()
        window.ignoresMouseEvents = false // must receive clicks so the cat is tappable
        window.animationBehavior = .none // avoid AppKit's implicit close/order animations entirely
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let container = ClickCatchingView(frame: NSRect(origin: .zero, size: rect.size))

        catView = CatView(frame: NSRect(x: (windowWidth - spriteSize) / 2, y: labelHeight,
                                         width: spriteSize, height: spriteSize))
        container.addSubview(catView)

        labelField = NSTextField(labelWithString: label)
        labelField.frame = NSRect(x: 4, y: 0, width: windowWidth - 8, height: labelHeight)
        labelField.alignment = .center
        labelField.font = .systemFont(ofSize: 11, weight: .semibold)
        labelField.textColor = .white
        labelField.lineBreakMode = .byTruncatingTail
        labelField.wantsLayer = true
        labelField.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.55).cgColor
        labelField.layer?.cornerRadius = 5
        labelField.layer?.masksToBounds = true
        container.addSubview(labelField)

        container.onClick = { [weak self] in self?.presentSummary() }

        window.contentView = container
        clampToScreenBounds()
        window.setFrameOrigin(NSPoint(x: position.x - windowWidth / 2,
                                       y: position.y - spriteSize / 2 - labelHeight))
        window.orderFrontRegardless()
    }

    func startRoaming() {
        idleUntil = now() + Double.random(in: 1...3)
        catView.setSprite(CatSprite.image(for: .rest, flip: facingLeft, status: status))
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stopRoaming() {
        timer?.invalidate()
        timer = nil
    }

    var name: String { projectName }

    /// Current on-screen position — read by AppDelegate when rebuilding every
    /// cat at a new scale, so each one respawns exactly where it was standing.
    var currentPosition: CGPoint { position }

    /// Updates this cat's project name and the text shown on its label.
    func rename(to newName: String) {
        projectName = newName
        labelField.stringValue = newName
    }

    /// Changes this cat's status color. Takes effect on the next pose update
    /// (within one tick), no need to force-redraw here.
    func setStatus(_ newStatus: CatStatus) {
        status = newStatus
    }

    /// Sets (or clears, with nil) the fixed spot this cat should walk to and hold
    /// while "왼쪽 정렬" mode is on. Ignored while that mode is off.
    func setAlignedTarget(_ target: CGPoint?) {
        alignedTarget = target
    }

    /// Tears the cat down entirely: stops its timer and closes its window.
    func close() {
        stopRoaming()
        window.close() // orderOut + close together raced with window-close animation teardown and crashed
    }

    /// Re-reads AppSettings.shared.sendToBackEnabled and updates this window's level.
    /// Call after toggling the "화면 맨 뒤로 이동" setting.
    func applyWindowLevel() {
        window.level = CatWindow.windowLevel()
    }

    /// Normal floating (always on top) by default; when sendToBackEnabled is on,
    /// drops to the desktop-icon level so real app windows cover the cat instead
    /// of the cat blocking clicks on whatever's behind it.
    private static func windowLevel() -> NSWindow.Level {
        guard AppSettings.shared.sendToBackEnabled else { return .floating }
        return NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }

    // MARK: - Behavior tick

    private func tick() {
        let t = now()

        let isRoamingException = AppSettings.shared.roamingExceptions.contains(projectName)
        if AppSettings.shared.alignedEnabled, !isRoamingException, let target = alignedTarget {
            // Lined-up mode: walk to the assigned slot and hold there, ignore chase/wander entirely.
            // Cats in roamingExceptions skip this branch and behave normally below.
            state = .idle
            _ = moveToward(target, speed: alignSpeed)
            updatePose(at: t)
            window.setFrameOrigin(NSPoint(x: position.x - windowWidth / 2,
                                           y: position.y - spriteSize / 2 - labelHeight))
            return
        }

        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - position.x
        let dy = mouse.y - position.y
        let distanceToMouse = (dx * dx + dy * dy).squareRoot()
        let chaseEnabled = AppSettings.shared.chaseEnabled

        switch state {
        case .idle:
            if chaseEnabled && distanceToMouse < chaseTriggerRadius && distanceToMouse > restRadius {
                state = .chase
            } else if t >= idleUntil {
                wanderTarget = pickWanderTarget()
                state = .wander
            }

        case .wander:
            if chaseEnabled && distanceToMouse < chaseTriggerRadius && distanceToMouse > restRadius {
                state = .chase
                wanderTarget = nil
            } else if let target = wanderTarget {
                if moveToward(target, speed: wanderSpeed) {
                    state = .idle
                    idleUntil = t + Double.random(in: 1.5...4)
                    wanderTarget = nil
                }
            }

        case .chase:
            if !chaseEnabled {
                // Toggled off mid-chase — stop immediately instead of finishing the approach.
                state = .idle
                idleUntil = t + 0.5
            } else if distanceToMouse <= restRadius {
                state = .idle
                idleUntil = t + Double.random(in: 1.5...4)
            } else if distanceToMouse > chaseGiveUpRadius {
                // Cursor jumped far away (e.g. switched display/space) — stop chasing.
                state = .idle
                idleUntil = t + 0.5
            } else {
                _ = moveToward(CGPoint(x: mouse.x, y: mouse.y), speed: chaseSpeed)
            }
        }

        updatePose(at: t)
        window.setFrameOrigin(NSPoint(x: position.x - windowWidth / 2,
                                       y: position.y - spriteSize / 2 - labelHeight))
    }

    /// Moves `position` toward `target` and returns true once it has arrived.
    @discardableResult
    private func moveToward(_ target: CGPoint, speed: CGFloat) -> Bool {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > 4 else { return true }

        let step = min(distance, speed * CGFloat(tickInterval))
        position.x += dx / distance * step
        position.y += dy / distance * step
        facingLeft = dx < 0
        clampToScreenBounds()
        return false
    }

    private func clampToScreenBounds() {
        let bounds = CatWindow.screenUnion()
        let halfWidth = windowWidth / 2
        position.x = min(max(position.x, bounds.minX + halfWidth), bounds.maxX - halfWidth)
        position.y = min(max(position.y, bounds.minY + spriteSize / 2 + labelHeight), bounds.maxY - spriteSize / 2)
    }

    private func pickWanderTarget() -> CGPoint {
        let bounds = CatWindow.screenUnion()
        let halfWidth = windowWidth / 2
        let radius = CGFloat.random(in: 150...400)
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let target = CGPoint(x: position.x + cos(angle) * radius, y: position.y + sin(angle) * radius)
        return CGPoint(
            x: min(max(target.x, bounds.minX + halfWidth), bounds.maxX - halfWidth),
            y: min(max(target.y, bounds.minY + spriteSize / 2 + labelHeight), bounds.maxY - spriteSize / 2)
        )
    }

    private func updatePose(at t: TimeInterval) {
        let swapInterval: TimeInterval = state == .idle ? 0.9 : 0.25
        if t - lastPoseSwapTime > swapInterval {
            showTailFlick.toggle()
            lastPoseSwapTime = t
        }
        let pose: CatSprite.Pose = state == .idle
            ? (showTailFlick ? .blink : .rest)
            : (showTailFlick ? .tailFlick : .rest)
        catView.setSprite(CatSprite.image(for: pose, flip: facingLeft, status: status))
    }

    private func presentSummary() {
        guard AppSettings.shared.clickSummaryEnabled else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "\(projectName)  \(status.emoji) \(status.label)"
        alert.addButton(withTitle: "닫기")

        // Long summaries used to go straight into `informativeText`, which has no
        // scrolling — past a certain length the alert just grows taller than the
        // screen, taking its own "닫기" button (and even the alert's titlebar
        // close control) off-screen with it, unreachable. A fixed-size scrollable
        // accessory view keeps the alert's overall size constant no matter how
        // long the summary text is, so its buttons always stay reachable.
        let scrollView = NSTextView.scrollableTextView()
        scrollView.frame = NSRect(x: 0, y: 0, width: 420, height: 280)
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        if let textView = scrollView.documentView as? NSTextView {
            textView.string = ProjectSummaries.summary(for: projectName)
            textView.isEditable = false
            textView.font = .systemFont(ofSize: 13)
            textView.textContainerInset = NSSize(width: 6, height: 6)
        }
        alert.accessoryView = scrollView

        alert.runModal()
    }

    private func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    private static func screenUnion() -> CGRect {
        NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
    }
}
