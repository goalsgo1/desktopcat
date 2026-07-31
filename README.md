# DesktopCat 🐱

맥 화면(모든 연결된 모니터 포함) 위를 자유롭게 돌아다니는 픽셀 고양이 데스크탑 펫.
프로젝트마다 고양이 한 마리씩, 이름표를 달고 따로따로 돌아다니며, 클릭하면 그 프로젝트의
진행상황 요약을 보여준다. 서명·공증된 앱이라 다운로드해서 바로 실행 가능(Gatekeeper 경고 없음).

## 기능

- 프로젝트당 고양이 한 마리, 각자 독립적으로 배회/추격
- **평소**: 랜덤한 지점으로 어슬렁어슬렁 걸어갔다가 잠깐 앉아서 쉬는 걸 반복 (배회)
- **마우스 커서가 가까이 오면**: 커서를 향해 달려가서 근처에 도착하면 다시 앉음 (추격)
- 모니터가 여러 대여도 전체 화면을 자유롭게 넘나듦
- **클릭하면** 그 프로젝트의 진행상황 요약을 보여줌 — 텍스트 파일 기반이라 앱 재시작 없이 바로 수정 가능
- **왼쪽 정렬 (고정)**: 클릭 한 번으로 모든 고양이를 화면 왼쪽에 줄 세우고 멈춤 — 몇 개 프로젝트를 돌리는지 한눈에 확인
- **화면 맨 뒤로 이동**: 고양이가 다른 앱 창 뒤로 내려가서 클릭을 방해하지 않게 함
- 패널에서 프로젝트 추가/제거, 진행상황 편집까지 전부 GUI로
- **업데이트 확인**: GitHub Releases에서 최신 버전을 확인해서, 새 버전이 있으면 다운로드 → 설치 → 자동 재시작까지 한 번에

## 요구 사항

- macOS 12.0 (Monterey) 이상

## 설치

[Releases](https://github.com/goalsgo1/desktopcat/releases)에서 최신 `DesktopCat-*.zip` 다운로드 → 압축 풀기 →
`DesktopCat.app`을 `/Applications`로 이동 → 실행.

Developer ID로 서명 + 공증까지 된 앱이라 "확인되지 않은 개발자" 경고 없이 바로 열린다.

⚠️ **`/Applications`로 옮기지 않고 다운로드 폴더에서 바로 실행하면 안 된다.** macOS가 앱을
임시 읽기 전용 위치(App Translocation)에서 실행시켜서 **"업데이트 확인"과 "앱 삭제..."가
동작하지 않는다** ("couldn't be moved to 'd'..." 오류). 앱을 실행하기 전에 반드시 Finder에서
`DesktopCat.app`을 `/Applications`로 옮긴 뒤 거기서 실행할 것.

## 사용법

- 메뉴바 🐱×N 아이콘 **좌클릭**: 설정 패널 열기/닫기 (프로젝트 추가/제거, 진행상황 편집, 각종 토글)
- 메뉴바 아이콘 **우클릭**: 빠른 종료 메뉴
- 고양이(또는 이름표) **클릭**: 그 프로젝트 진행상황 요약 보기
- 로그인 시 자동 실행을 원하면 `.app`을 로그인 항목에 등록하면 됨 (시스템 설정 → 일반 → 로그인 항목)

## 업데이트

설정 패널의 **업데이트 확인** 버튼 → 최신 버전이 있으면 확인 창 → **업데이트** 누르면 다운로드부터
설치, 재시작까지 자동으로 처리된다. Sparkle 같은 별도 프레임워크 없이 GitHub Releases API를 직접
호출하는 가벼운 자체 구현. 정식 설치된 `.app`에서 실행 중일 때만 동작하며, 다운로드·압축 해제·검증이
전부 끝난 뒤에야 기존 앱을 건드리므로(휴지통 이동 후 교체) 중간에 실패해도 기존 설치는 그대로 남는다.

## 삭제

**가장 쉬운 방법**: 설정 패널 맨 아래 빨간 글씨 **앱 삭제...** 버튼 → 확인하면 앱과 설정 파일
(`~/.desktopcat`)이 한 번에 휴지통으로 이동하고 앱이 종료된다. 완전 삭제가 아니라 휴지통 이동이라
복구도 가능. (정식 설치된 `.app`에서 실행 중일 때만 동작함)

**수동으로 하려면**:
1. 메뉴바 🐱×N 아이콘 클릭 → **Quit Desktop Cat** (또는 아이콘 우클릭 → Quit) — Dock이 없는 메뉴바 전용
   앱이라 일반적인 Cmd+Q로는 안 꺼진다
2. `/Applications/DesktopCat.app` 삭제
3. (선택) 설정 파일까지 완전히 지우려면: `rm -rf ~/.desktopcat` — 프로젝트 로스터/진행상황 텍스트가
   들어있는 폴더로, 앱만 지워도 문제는 없지만 흔적 없이 지우려면 이것도 삭제
4. 로그인 항목에 등록해뒀다면 시스템 설정 → 일반 → 로그인 항목에서도 제거

## 소스에서 빌드하기

```bash
git clone https://github.com/goalsgo1/desktopcat.git
cd desktopcat
swift build -c release
./.build/release/DesktopCat &
```

서명·공증까지 된 `.app`으로 빌드하려면 (본인 Developer ID 필요):

```bash
export SIGN_IDENTITY="Developer ID Application: <이름> (<팀ID>)"
./scripts/build-app.sh      # build/DesktopCat.app 생성 + 서명
./scripts/notarize.sh       # Apple 공증 + staple (notarytool 자격증명 사전 등록 필요)
```

## 프로젝트 로스터 / 진행상황 편집

`~/.desktopcat/projects.txt`에 한 줄에 프로젝트 이름 하나씩 적혀 있고, 앱 시작 시 그 줄 수만큼
고양이를 만든다. 앱 안 설정 패널의 리스트+입력창으로 추가/제거하면 즉시 반영되고, 파일을
직접 수정하는 것도 가능(그 경우는 재시작 필요).

각 프로젝트의 진행상황은 `~/.desktopcat/summaries/<프로젝트 이름>.txt`에 저장되며, 설정 패널의
**편집** 버튼으로 앱 안에서 바로 고칠 수도 있다. 클릭할 때마다 그 시점 파일 내용을 새로 읽으므로
재시작이 필요 없다.

## 구현 메모

- 순수 AppKit(Swift Package, Xcode 프로젝트 아님). 이미지 에셋 없이 `CatSprite.swift`에서 16×16
  픽셀 그리드를 코드로 그려 캐싱한 `NSImage`를 사용.
- 창은 `borderless` + `collectionBehavior = [.canJoinAllSpaces, ...]`로 모든 Space 위에 떠 있다.
  클릭을 받아야 해서 `ignoresMouseEvents = false`이고, 클릭은 `NSAlert` 모달로 요약을 띄운다.
- 마우스 위치는 전역 이벤트 모니터 대신 `NSEvent.mouseLocation` 폴링(30fps 타이머)으로 읽는다 —
  별도 손쉬운 사용/입력 모니터링 권한이 필요 없다.
- "화면 맨 뒤로 이동"은 `CGWindowLevelForKey(.desktopIconWindow)` 레벨로 내려서 일반 앱 창이
  항상 위에 그려지게 하는 방식.

## 라이선스

MIT License — [LICENSE](LICENSE) 참고
