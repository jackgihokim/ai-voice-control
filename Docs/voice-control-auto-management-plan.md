# 음성인식 자동 관리 시스템 구현 계획

## 1. 개요

### 1.1 목표
- Apple Speech Framework의 60초 제한을 자동으로 관리
- 사용자가 Start/Stop 버튼을 누르지 않아도 되는 자동 시스템 구축
- 웨이크워드와 Enter 키로 타이머 자동 리셋
- 남은 시간을 시각적으로 표시하는 플로팅 UI

### 1.2 핵심 문제 해결
- **60초 제한**: 58초마다 자동 재시작으로 해결
- **State 관리**: Single Source of Truth 패턴으로 통합
- **UI 가시성**: 플로팅 윈도우로 항상 표시
- **사용자 경험**: 자동화로 편의성 극대화

## 2. 시스템 아키텍처

### 2.1 컴포넌트 구조
```
┌─────────────────────────────────────────┐
│         VoiceControlStateManager        │ ← Single Source of Truth
│  - isListening: Bool                    │
│  - remainingTime: Int                   │
│  - autoStartEnabled: Bool               │
└──────────────┬──────────────────────────┘
               │
    ┌──────────┴───────────┬─────────────┬──────────────┐
    ↓                      ↓             ↓              ↓
┌──────────┐   ┌──────────────┐  ┌──────────┐  ┌──────────────┐
│ MenuBar  │   │VoiceRecognition│ │Floating │  │WakeWord      │
│ViewModel│   │Engine          │ │Timer    │  │Detector      │
└──────────┘   └────────────────┘ └─────────┘  └──────────────┘
```

### 2.2 데이터 플로우
```
앱 시작
  ├─→ autoStartEnabled 확인
  │     └─→ true: startListening() 자동 실행
  │
  ├─→ 플로팅 타이머 윈도우 생성
  │     └─→ 58초 카운트다운 시작
  │
  └─→ NotificationCenter 옵저버 등록
        ├─→ 웨이크워드 감지 리스너
        └─→ Enter 키 이벤트 리스너
```

## 3. 구현 상세

### 3.1 VoiceControlStateManager (새 파일)
```swift
// Path: AIVoiceControl/Core/Managers/VoiceControlStateManager.swift

@MainActor
class VoiceControlStateManager: ObservableObject {
    static let shared = VoiceControlStateManager()
    
    // MARK: - Published State
    @Published var isListening = false
    @Published var remainingTime = 58
    @Published var autoStartEnabled = true
    @Published var showFloatingTimer = true
    
    // MARK: - Private Properties
    private var voiceEngine: VoiceRecognitionEngine?
    private var countdownTimer: Timer?
    private var stateQueue = DispatchQueue(label: "voicecontrol.state.queue")
    private var isTransitioning = false
    
    // MARK: - Constants
    private let maxTime = 58
    private let warningThreshold = 10
    
    // MARK: - Initialization
    private init() {
        setupNotificationObservers()
        loadUserSettings()
    }
    
    // MARK: - Public Methods
    func startListening() async throws {
        guard !isListening else { return }
        
        isListening = true
        try await voiceEngine?.startListening()
        startCountdownTimer()
        
        NotificationCenter.default.post(
            name: .voiceControlStateChanged,
            object: nil,
            userInfo: ["isListening": true]
        )
    }
    
    func stopListening() {
        guard isListening else { return }
        
        isListening = false
        voiceEngine?.stopListening()
        stopCountdownTimer()
        
        NotificationCenter.default.post(
            name: .voiceControlStateChanged,
            object: nil,
            userInfo: ["isListening": false]
        )
    }
    
    func resetTimer() async {
        // 짧은 중단 후 재시작으로 타이머 리셋
        stopListening()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
        try? await startListening()
    }
    
    // MARK: - Private Methods
    private func startCountdownTimer() {
        stopCountdownTimer()
        remainingTime = maxTime
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.remainingTime -= 1
                
                // 경고 알림
                if self.remainingTime == self.warningThreshold {
                    self.showWarning()
                }
                
                // 시간 만료 (자동 재시작 전)
                if self.remainingTime <= 0 {
                    self.remainingTime = self.maxTime
                }
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        remainingTime = maxTime
    }
    
    private func setupNotificationObservers() {
        // 웨이크워드 감지 시 리셋
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWakeWordDetected),
            name: .wakeWordDetected,
            object: nil
        )
        
        // Enter 키 입력 시 리셋
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnterKeyPressed),
            name: .enterKeyPressed,
            object: nil
        )
    }
    
    @objc private func handleWakeWordDetected() {
        Task {
            await resetTimer()
        }
    }
    
    @objc private func handleEnterKeyPressed() {
        Task {
            await resetTimer()
        }
    }
}
```

### 3.2 플로팅 타이머 윈도우
```swift
// Path: AIVoiceControl/Features/FloatingTimer/FloatingTimerWindow.swift

class FloatingTimerWindow: NSWindow {
    private var timerView: FloatingTimerView!
    
    init() {
        let contentRect = NSRect(x: 100, y: 100, width: 200, height: 40)
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupView()
        setupBindings()
    }
    
    private func setupWindow() {
        // 항상 최상위
        level = .floating
        
        // 투명 배경
        isOpaque = false
        backgroundColor = NSColor.clear
        
        // 모든 Space에서 표시
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // 클릭 통과
        ignoresMouseEvents = false
        
        // 위치 복원
        let savedPosition = UserSettings.load().floatingTimerPosition
        setFrameOrigin(savedPosition)
    }
}

// Path: AIVoiceControl/Features/FloatingTimer/FloatingTimerView.swift

struct FloatingTimerView: View {
    @ObservedObject private var stateManager = VoiceControlStateManager.shared
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 10) {
            // 드래그 핸들
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .onDrag {
                    isDragging = true
                    return NSItemProvider()
                }
            
            // 프로그레스 바
            ProgressView(value: Double(stateManager.remainingTime), total: 58)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 100)
                .tint(progressColor)
            
            // 시간 표시
            Text("\(stateManager.remainingTime)s")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(timeColor)
                .frame(width: 35)
            
            // 일시정지/재생 버튼
            Button(action: toggleListening) {
                Image(systemName: stateManager.isListening ? "pause.circle" : "play.circle")
                    .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .shadow(radius: 4, x: 0, y: 2)
    }
    
    private var progressColor: Color {
        if stateManager.remainingTime <= 10 {
            return .red
        } else if stateManager.remainingTime <= 30 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var timeColor: Color {
        stateManager.remainingTime <= 10 ? .red : .primary
    }
    
    private var borderColor: Color {
        if stateManager.remainingTime <= 10 {
            return .red.opacity(0.5)
        }
        return Color(NSColor.separatorColor)
    }
}
```

### 3.3 메뉴바 통합
```swift
// MenuBarViewModel.swift 수정

@MainActor
class MenuBarViewModel: ObservableObject {
    private let stateManager = VoiceControlStateManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // State를 StateManager에서 구독
    @Published var isListening: Bool = false
    @Published var remainingTime: Int = 58
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // StateManager의 상태를 구독
        stateManager.$isListening
            .assign(to: &$isListening)
        
        stateManager.$remainingTime
            .assign(to: &$remainingTime)
    }
    
    func toggleListening() {
        Task {
            if stateManager.isListening {
                stateManager.stopListening()
            } else {
                try? await stateManager.startListening()
            }
        }
    }
}

// MenuBarView.swift 수정

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    
    var body: some View {
        VStack {
            // 상태 표시
            HStack {
                Circle()
                    .fill(viewModel.isListening ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.isListening ? "Listening" : "Stopped")
                
                if viewModel.isListening {
                    Text("(\(viewModel.remainingTime)s)")
                        .foregroundColor(viewModel.remainingTime < 10 ? .red : .secondary)
                }
            }
            
            // 제어 버튼
            Button(viewModel.isListening ? "Stop Listening" : "Start Listening") {
                viewModel.toggleListening()
            }
        }
    }
}
```

### 3.4 웨이크워드 감지 통합
```swift
// WakeWordDetector.swift 수정

private func handleWakeWordDetection(app: AppConfiguration) {
    // 기존 코드...
    
    // 타이머 리셋 알림
    NotificationCenter.default.post(
        name: .wakeWordDetected,
        object: nil,
        userInfo: ["app": app]
    )
    
    #if DEBUG
    print("🔄 Wake word detected - timer will reset")
    #endif
}
```

### 3.5 Enter 키 감지
```swift
// KeyboardEventMonitor.swift (새 파일)

class KeyboardEventMonitor {
    private var eventMonitor: Any?
    
    func startMonitoring() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 36 { // Enter key
                // 활성 앱이 대상 앱인지 확인
                if self.isTargetAppActive() {
                    NotificationCenter.default.post(
                        name: .enterKeyPressed,
                        object: nil
                    )
                }
            }
            return event
        }
    }
    
    private func isTargetAppActive() -> Bool {
        let activeApp = NSWorkspace.shared.frontmostApplication
        let targetApps = UserSettings.load().appConfigurations
        
        return targetApps.contains { config in
            config.bundleIdentifier == activeApp?.bundleIdentifier
        }
    }
}
```

### 3.6 AppDelegate 수정
```swift
// AppDelegate.swift

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private let stateManager = VoiceControlStateManager.shared
    private var floatingWindow: FloatingTimerWindow?
    private var keyboardMonitor = KeyboardEventMonitor()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 기존 초기화 코드...
        
        // 자동 시작 확인
        let settings = UserSettings.load()
        if settings.autoStartListening {
            Task {
                try? await stateManager.startListening()
            }
        }
        
        // 플로팅 타이머 윈도우 생성
        if settings.showFloatingTimer {
            floatingWindow = FloatingTimerWindow()
            floatingWindow?.orderFront(nil)
        }
        
        // 키보드 이벤트 모니터링 시작
        keyboardMonitor.startMonitoring()
    }
}
```

## 4. Settings UI 추가

### 4.1 자동 관리 설정
```swift
// GeneralSettingsTab.swift 추가

Section("Voice Control Automation") {
    Toggle("Auto-start listening on launch", isOn: $viewModel.userSettings.autoStartListening)
        .help("Automatically start voice recognition when the app launches")
    
    Toggle("Show floating timer", isOn: $viewModel.userSettings.showFloatingTimer)
        .help("Display a floating timer showing remaining time")
    
    Toggle("Reset timer on wake word", isOn: $viewModel.userSettings.resetOnWakeWord)
        .help("Reset 58-second timer when wake word is detected")
    
    Toggle("Reset timer on Enter key", isOn: $viewModel.userSettings.resetOnEnterKey)
        .help("Reset timer when Enter key is pressed in target apps")
    
    HStack {
        Text("Warning threshold:")
        Slider(
            value: $viewModel.userSettings.warningThreshold,
            in: 5...30,
            step: 5
        )
        Text("\(Int(viewModel.userSettings.warningThreshold))s")
    }
    .help("Show warning when this many seconds remain")
}
```

### 4.2 플로팅 윈도우 설정
```swift
Section("Floating Timer Settings") {
    // 위치 프리셋
    Picker("Position:", selection: $viewModel.floatingPosition) {
        Text("Top Left").tag(FloatingPosition.topLeft)
        Text("Top Right").tag(FloatingPosition.topRight)
        Text("Bottom Left").tag(FloatingPosition.bottomLeft)
        Text("Bottom Right").tag(FloatingPosition.bottomRight)
        Text("Custom").tag(FloatingPosition.custom)
    }
    
    // 투명도
    Slider(
        value: $viewModel.userSettings.floatingTimerOpacity,
        in: 0.3...1.0,
        step: 0.1
    ) {
        Text("Opacity:")
    }
    
    // 크기
    Picker("Size:", selection: $viewModel.floatingSize) {
        Text("Compact").tag(FloatingSize.compact)
        Text("Normal").tag(FloatingSize.normal)
        Text("Large").tag(FloatingSize.large)
    }
}
```

## 5. 테스트 시나리오

### 5.1 자동 시작 테스트
1. Settings에서 "Auto-start listening" 활성화
2. 앱 재시작
3. 자동으로 음성인식 시작 확인
4. 플로팅 타이머 표시 확인

### 5.2 타이머 리셋 테스트
1. 음성인식 실행 중 상태
2. 웨이크워드 말하기 → 타이머 58초로 리셋 확인
3. 텍스트 입력 후 Enter → 타이머 58초로 리셋 확인
4. 메뉴바에서 Stop/Start → 타이머 리셋 확인

### 5.3 58초 자동 재시작 테스트
1. 음성인식 시작
2. 58초 대기
3. 자동 재시작 확인 (타이머 0 → 58)
4. 음성인식 계속 작동 확인

### 5.4 플로팅 윈도우 테스트
1. 다른 앱 활성화
2. 플로팅 타이머가 계속 보이는지 확인
3. 드래그로 위치 이동 가능한지 확인
4. 재시작 시 위치 복원 확인

## 6. 예상 문제점과 해결책

### 6.1 문제: 0.5초 재시작 공백
- **현상**: 58초 재시작 시 0.5초간 음성 손실
- **해결**: 버퍼링 시스템 구현 (향후)
- **임시방안**: 사용자에게 57초에 경고

### 6.2 문제: State 동기화
- **현상**: 여러 컴포넌트 간 상태 불일치
- **해결**: Single Source of Truth (StateManager)
- **검증**: Unit Test 작성

### 6.3 문제: 플로팅 윈도우 가시성
- **현상**: 풀스크린 앱에서 가려짐
- **해결**: NSWindow.Level.screenSaver 사용
- **대안**: 메뉴바 아이콘에 숫자 표시

### 6.4 문제: 성능 영향
- **현상**: 1초마다 타이머 업데이트
- **해결**: 효율적인 렌더링 (SwiftUI diffing)
- **모니터링**: Instruments로 CPU 사용률 체크

## 7. 구현 우선순위

### Phase 1 (필수)
1. VoiceControlStateManager 구현
2. 자동 시작 기능
3. 메뉴바 Start/Stop 통합
4. 58초 타이머 시각화

### Phase 2 (권장)
1. 플로팅 타이머 윈도우
2. 웨이크워드 리셋
3. Enter 키 리셋
4. Settings UI

### Phase 3 (선택)
1. 타이머 위치 커스터마이징
2. 경고 알림 시스템
3. 통계 수집
4. 음성 피드백

## 8. 코드 변경 요약

### 새로 생성할 파일
- `VoiceControlStateManager.swift`
- `FloatingTimerWindow.swift`
- `FloatingTimerView.swift`
- `KeyboardEventMonitor.swift`

### 수정할 파일
- `AppDelegate.swift` - 자동 시작 로직
- `MenuBarViewModel.swift` - StateManager 통합
- `MenuBarView.swift` - 타이머 표시
- `WakeWordDetector.swift` - 리셋 알림
- `UserSettings.swift` - 새 설정 필드
- `GeneralSettingsTab.swift` - 자동화 설정 UI

### Notification 추가
- `.voiceControlStateChanged`
- `.wakeWordDetected`
- `.enterKeyPressed`
- `.timerWarning`

## 9. 향후 개선 사항

### 9.1 고급 기능
- 음성 명령으로 타이머 리셋 ("리셋", "다시")
- 머신러닝 기반 사용 패턴 학습
- 앱별 타이머 설정
- 멀티 유저 프로필

### 9.2 접근성
- VoiceOver 지원
- 키보드 단축키
- 색맹 모드
- 고대비 모드

### 9.3 성능 최적화
- 백그라운드 모드 최적화
- 배터리 사용량 최소화
- 메모리 사용 최적화
- 네트워크 사용 최소화

---

*작성일: 2025-08-16*
*작성자: Claude Code*
*버전: 1.0*