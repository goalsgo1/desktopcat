import AppKit

/// Opened from the "정보" button in the settings panel. A read-only, scrollable
/// page explaining every feature in one place — for a first-time user who just
/// sees a grid of buttons and colored cats with no idea what any of it does.
final class InfoPanel: NSObject {
    private let window: NSWindow

    override init() {
        let width: CGFloat = 380
        let height: CGFloat = 460

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                           styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "DesktopCat 사용법"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.minSize = NSSize(width: 300, height: 260)

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.autoresizesSubviews = true

        let scrollView = NSScrollView(frame: NSRect(x: 16, y: 52, width: width - 32, height: height - 68))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.textStorage?.setAttributedString(InfoPanel.buildContent())
        scrollView.documentView = textView

        container.addSubview(scrollView)

        let closeButton = NSButton(title: "닫기", target: nil, action: nil)
        closeButton.frame = NSRect(x: width - 92, y: 16, width: 76, height: 28)
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        closeButton.autoresizingMask = [.minXMargin]
        container.addSubview(closeButton)

        window.contentView = container

        super.init()

        closeButton.target = self
        closeButton.action = #selector(closeTapped)
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

    @objc private func closeTapped() {
        window.orderOut(nil)
    }

    // MARK: - Content

    private static func buildContent() -> NSAttributedString {
        let result = NSMutableAttributedString()

        func heading(_ text: String) {
            result.append(NSAttributedString(string: "\(text)\n", attributes: [
                .font: NSFont.boldSystemFont(ofSize: 13),
            ]))
        }
        func body(_ text: String) {
            result.append(NSAttributedString(string: "\(text)\n\n", attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor,
            ]))
        }
        func bullet(_ text: String) {
            result.append(NSAttributedString(string: "•  \(text)\n", attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.labelColor,
            ]))
        }

        heading("고양이는 뭘 하는 거예요?")
        body("배포/운영 중인 프로젝트마다 고양이 한 마리씩 화면 위를 돌아다녀요. "
            + "평소엔 어슬렁어슬렁 걷다가 쉬고, 마우스 커서가 가까이 오면 쫓아와요. "
            + "이름표나 고양이를 클릭하면 그 프로젝트의 진행상황 요약이 떠요.")

        heading("털 색은 무슨 뜻이에요?")
        bullet("⚪ 하얀색 — 애매/미정. 아직 상태를 안 정했거나 계속할지 자체가 불명확함")
        bullet("🔴 빨간색 — 정지. 다음에 뭘 해야 할지 불분명한 채 며칠~몇 주째 방치됨")
        bullet("🟡 노란색 — 대기중. 할 일은 다 했고 남(심사·승인 등)의 응답만 기다리는 중")
        bullet("🔵 파란색 — 진행중. 계속 손으로 작업해야 앞으로 나가는 활성 작업")
        bullet("🟢 초록색 — 자동가동. 예약(launchd 등)으로 손 안 대도 알아서 돌아가는 중")
        bullet("🟣 보라색 — 완료/유지보수. 다 만들었고 버그 나올 때만 손대는 상태")
        result.append(NSAttributedString(string: "\n"))

        heading("프로젝트 목록")
        body("행을 클릭하면 아래 입력창에 이름이 채워져요(제거할 때 편함). "
            + "오른쪽 이모지 드롭다운으로 그 고양이의 색을 바로 바꿀 수 있고, "
            + "\"편집\" 버튼으로 진행상황 요약 텍스트를 직접 고칠 수 있어요(이름 변경도 가능).")

        heading("추가 / 제거")
        body("이름을 입력하고 \"추가\"를 누르면 그 자리에서 새 고양이가 생겨요. "
            + "이름을 입력(또는 목록에서 선택)하고 \"제거\"를 누르면 그 고양이가 즉시 사라져요.")

        heading("마우스 추격")
        body("끄면 어떤 고양이도 커서를 쫓아오지 않고 배회만 해요.")

        heading("클릭 시 진행상황 요약 보기")
        body("끄면 고양이를 클릭해도 아무것도 안 떠요.")

        heading("왼쪽 정렬 (고정)")
        body("켜면 모든 고양이가 화면 왼쪽 가장자리에 세로로 줄을 서요. "
            + "옆에 나타나는 \"목록 보기\" 버튼에서 특정 고양이를 체크하면, "
            + "그 고양이만 줄에서 빠져서 평소처럼 자유롭게 돌아다녀요.")

        heading("화면 맨 뒤로 이동")
        body("켜면 고양이가 데스크탑 아이콘 레벨로 내려가서, Finder·브라우저 같은 "
            + "일반 앱 창이 항상 고양이보다 위에 그려져요 — 창 뒤 버튼을 고양이가 "
            + "가려서 못 누르는 문제를 해결할 때 켜세요.")

        heading("업데이트 확인 / 종료 / 앱 삭제")
        body("\"업데이트 확인\"은 새 버전이 있으면 알려주고 설치까지 도와줘요. "
            + "\"앱 삭제\"는 앱과 설정 파일(~/.desktopcat)을 전부 휴지통으로 보내요 "
            + "(휴지통에서 복구 가능).")

        return result
    }
}
