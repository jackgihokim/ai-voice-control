# 음성 인식 리셋 플로우 분석

## 목차
1. [시스템 아키텍처 개요](#시스템-아키텍처-개요)
2. [startListening() 실행 플로우](#startlistening-실행-플로우)
3. [stopListening() 실행 플로우](#stoplistening-실행-플로우)
4. [리셋 트리거와 조건](#리셋-트리거와-조건)
5. [리셋 타입별 동작](#리셋-타입별-동작)
6. [실제 시나리오 예시](#실제-시나리오-예시)
7. [상태 플로우 다이어그램](#상태-플로우-다이어그램)

---

## 시스템 아키텍처 개요

음성 인식 시스템은 다음 핵심 컴포넌트들로 구성됩니다:

### 핵심 컴포넌트
- **VoiceRecognitionEngine** (`VoiceRecognitionEngine.swift`): 실제 음성 인식 처리
- **VoiceControlStateManager** (`VoiceControlStateManager.swift`): 전역 상태 관리
- **WakeWordDetector** (`WakeWordDetector.swift`): 웨이크워드 감지 및 명령 버퍼링
- **MenuBarViewModel** (`MenuBarViewModel.swift`): UI와 비즈니스 로직 연결

### 상태 관리 계층
```
MenuBarViewModel (UI Layer)
    ↓
VoiceControlStateManager (State Management)
    ↓
VoiceRecognitionEngine (Core Engine)
    ↓
WakeWordDetector (Detection Logic)
```

---

## startListening() 실행 플로우

### 1. 진입점: VoiceControlStateManager.startListening()
```swift
// VoiceControlStateManager.swift:56-87
func startListening() async throws {
    guard !isListening && !isTransitioning else { return }
    
    isTransitioning = true
    defer { isTransitioning = false }
    
    isListening = true
    
    // 음성 엔진 시작
    if let engine = voiceEngine {
        try await engine.startListening()
    }
    
    // 카운트다운 타이머 시작
    startCountdownTimer()
    
    // 상태 변경 알림 전송
    NotificationCenter.default.post(
        name: .voiceControlStateChanged,
        object: nil,
        userInfo: ["isListening": true]
    )
}
```

### 2. VoiceRecognitionEngine.startListening() 상세 플로우

#### 2.1 권한 확인 단계
```swift
// VoiceRecognitionEngine.swift:142-170
// 1. 마이크 권한 확인
let microphoneStatus = await PermissionManager.shared.checkMicrophonePermission()
guard microphoneStatus == .authorized else {
    throw VoiceRecognitionError.noMicrophoneAccess
}

// 2. 음성 인식 권한 확인
let speechStatus = await PermissionManager.shared.checkSpeechRecognitionPermission()
guard speechStatus == .authorized else {
    throw VoiceRecognitionError.speechRecognizerUnavailable
}

// 3. Speech Recognizer 가용성 확인
guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
    throw VoiceRecognitionError.speechRecognizerUnavailable
}
```

#### 2.2 Voice Isolation 설정
```swift
// VoiceRecognitionEngine.swift:173-175
await configureVoiceIsolation()  // 사용자 설정에 따라 Voice Isolation 활성화/비활성화
```

#### 2.3 오디오 엔진 시작
```swift
// VoiceRecognitionEngine.swift:294-335
private func startAudioEngine() async throws {
    // 1. Recognition Request 생성
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    recognitionRequest.shouldReportPartialResults = true
    recognitionRequest.requiresOnDeviceRecognition = true  // 60초 제한 우회
    
    // 2. 오디오 입력 노드 설정
    let inputNode = audioEngine.inputNode
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { 
        [weak self] buffer, _ in
        self?.recognitionRequest?.append(buffer)
        // 오디오 레벨 계산
        let level = self.calculateAudioLevel(buffer: buffer)
    }
    
    // 3. 오디오 엔진 시작
    audioEngine.prepare()
    try audioEngine.start()
    
    // 4. Recognition Task 시작
    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { 
        [weak self] result, error in
        self?.handleRecognitionResult(result: result, error: error)
    }
}
```

#### 2.4 자동 재시작 스케줄링
```swift
// VoiceRecognitionEngine.swift:419-430
private func scheduleAutomaticRestart() {
    restartTimer?.invalidate()
    restartTimer = Timer.scheduledTimer(
        withTimeInterval: maxContinuousTime,  // 59초
        repeats: false
    ) { _ in
        Task { @MainActor in
            await self.performScheduledRestart()
        }
    }
}
```

### 3. 실행 예시 (디버그 로그)
```
🎙️ StateManager: Starting voice recognition
🎤 Speech recognizer initialized
🎤 Locale: ko-KR
🎤 On-device recognition: true
🎤 Available: true
🔊 Voice Isolation: Enabled
✅ Voice recognition started
⏰ Automatic restart scheduled in 59.0 seconds
⏱️ Starting countdown timer: 59 seconds
```

---

## stopListening() 실행 플로우

### 1. 진입점: VoiceControlStateManager.stopListening()
```swift
// VoiceControlStateManager.swift:89-126
func stopListening() {
    guard isListening && !isTransitioning else { return }
    
    isTransitioning = true
    defer { isTransitioning = false }
    
    isListening = false
    
    // 음성 엔진 정지
    voiceEngine?.stopListening()
    
    // 카운트다운 타이머 정지
    stopCountdownTimer()
    
    // 리셋 알림 전송 (텍스트 버퍼 클리어)
    NotificationCenter.default.post(
        name: .voiceRecognitionReset,
        object: nil,
        userInfo: ["reason": "stopListening"]
    )
}
```

### 2. VoiceRecognitionEngine.stopListening() 상세 플로우
```swift
// VoiceRecognitionEngine.swift:195-224
func stopListening() {
    guard recognitionState == .listening else { return }
    
    recognitionState = .stopping
    
    // 1. 재시작 타이머 취소
    restartTimer?.invalidate()
    restartTimer = nil
    
    // 2. Recognition Task 정리
    cleanupRecognitionTask()
    
    // 3. 오디오 레벨 모니터링 중지
    stopAudioLevelMonitoring()
    
    // 4. Voice Isolation 정리
    if isVoiceIsolationEnabled {
        Task {
            try? await voiceIsolationManager.cleanupAudioSession()
        }
    }
    
    // 5. 상태 초기화
    isListening = false
    recognitionState = .idle
    audioLevel = 0.0
    isRestarting = false
}
```

### 3. Recognition Task 정리 과정
```swift
// VoiceRecognitionEngine.swift:472-494
private func cleanupRecognitionTask() {
    // 1. 기존 태스크 취소
    recognitionTask?.cancel()
    
    // 2. 오디오 요청 종료
    recognitionRequest?.endAudio()
    
    // 3. 오디오 엔진 정지
    audioEngine.stop()
    
    // 4. 오디오 탭 제거
    if audioEngine.inputNode.numberOfInputs > 0 {
        audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    // 5. 참조 정리
    recognitionTask = nil
    recognitionRequest = nil
}
```

---

## 리셋 트리거와 조건

### 1. 수동 트리거

#### 1.1 사용자가 음성 인식 토글
- **트리거**: 메뉴바 아이콘 클릭 또는 단축키
- **경로**: `MenuBarViewModel.toggleListening()` → `VoiceControlStateManager.toggleListening()`
- **동작**: 완전한 stop → start 사이클

#### 1.2 Refresh 버튼
- **트리거**: UI의 리프레시 버튼 클릭
- **경로**: `MenuBarViewModel.refreshListening()` → `VoiceControlStateManager.refreshListening()`
- **동작**: `completeReset(clearTextField: false)`

### 2. 자동 트리거

#### 2.1 59초 자동 재시작
```swift
// VoiceRecognitionEngine.swift:432-470
private func performScheduledRestart() async {
    guard isListening && !isRestarting else { return }
    
    isRestarting = true
    defer { isRestarting = false }
    
    // 현재 인식 정지
    recognitionState = .stopping
    cleanupRecognitionTask()
    
    // 0.5초 대기
    try? await Task.sleep(nanoseconds: 500_000_000)
    
    // 재시작
    if isListening {
        do {
            recognitionState = .starting
            try await startAudioEngine()
            recognitionState = .listening
            scheduleAutomaticRestart()  // 다음 재시작 스케줄
        } catch {
            recognitionState = .idle
            isListening = false
        }
    }
}
```

**트리거 조건**: 
- 연속 59초 음성 인식 (Apple의 60초 제한 회피)
- `maxContinuousTime = 59.0`

#### 2.2 최종 전사(isFinal) 후 재시작
```swift
// VoiceRecognitionEngine.swift:375-407
if result.isFinal {
    recognizedText = transcription
    
    // 사용자 설정에서 재시작 지연 시간 가져오기
    let userSettings = UserSettings.load()
    let restartDelay = userSettings.recognitionRestartDelay  // 기본값: 0.5초
    
    // 지연 후 재시작
    DispatchQueue.main.asyncAfter(deadline: .now() + restartDelay) {
        if self.isListening {
            Task {
                self.stopListening()
                try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1초
                try? await self.startListening()
            }
        }
    }
}
```

**트리거 조건**:
- Speech Recognition이 문장 끝 감지 (침묵 감지)
- `result.isFinal == true`

#### 2.3 웨이크워드 감지 리셋
```swift
// VoiceControlStateManager.swift:341-352
@objc private func handleWakeWordDetected(_ notification: Notification) {
    if let app = notification.userInfo?["app"] as? AppConfiguration {
        print("🎯 Wake word detected for \(app.name) - performing complete reset")
    }
    
    Task {
        // 웨이크워드 감지 시 음성인식 완전 리셋 (텍스트 필드는 유지)
        await completeReset(clearTextField: false)
    }
}
```

**트리거 조건**:
- 등록된 앱의 웨이크워드 감지
- 예: "Claude", "클로드", "Cursor" 등

#### 2.4 Enter 키 리셋
```swift
// VoiceControlStateManager.swift:354-364
@objc private func handleEnterKeyPressed(_ notification: Notification) {
    print("⏎ Enter key pressed - performing complete reset")
    
    Task {
        // Enter 키의 경우 텍스트 필드는 지우지 않음
        await completeReset(clearTextField: false)
    }
}
```

**트리거 조건**:
- 사용자가 Enter 키 입력 (명령 실행 완료)

#### 2.5 에러 복구 재시작
```swift
// VoiceRecognitionEngine.swift:337-354
private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
    if let error = error {
        self.error = .recognitionFailed(error.localizedDescription)
        
        // 서버 에러인 경우 재시작
        if (error as NSError).code == 203 {
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1초
                if isListening {
                    stopListening()
                    try? await startListening()
                }
            }
        }
    }
}
```

**트리거 조건**:
- Speech Recognition 서버 에러 (코드 203)
- 네트워크 일시 장애

---

## 리셋 타입별 동작

### 1. 타이머만 리셋 (resetTimerOnly)
```swift
// VoiceControlStateManager.swift:159-167
func resetTimerOnly() {
    // 타이머만 재시작, 음성 인식은 유지
    stopCountdownTimer()
    startCountdownTimer()
}
```

**사용 시나리오**: 
- 음성 인식은 계속 유지하면서 59초 타이머만 리셋
- UI 타이머 표시 갱신

### 2. 음성 인식 재시작 (refreshListening)
```swift
// VoiceControlStateManager.swift:149-156
func refreshListening() async {
    await completeReset(clearTextField: false)
}
```

**사용 시나리오**:
- 음성 인식 엔진 재시작
- 텍스트 필드는 유지

### 3. 완전 리셋 (completeReset)
```swift
// VoiceControlStateManager.swift:169-200
func completeReset(clearTextField: Bool = true) async {
    // 1. 음성 인식 정지
    stopListening()
    
    // 2. 모든 텍스트 버퍼와 클립보드 정리
    await clearAllTextBuffers()
    
    // 3. 활성 앱의 텍스트 필드 정리 (옵션)
    if clearTextField {
        await clearActiveAppTextField()
    }
    
    // 4. 0.5초 대기
    try? await Task.sleep(nanoseconds: 500_000_000)
    
    // 5. 음성 인식 재시작
    do {
        try await startListening()
    } catch {
        // 에러 처리
    }
}
```

**텍스트 버퍼 정리 과정**:
```swift
// VoiceControlStateManager.swift:202-224
private func clearAllTextBuffers() async {
    // TextInputAutomator 리셋
    TextInputAutomator.shared.resetIncrementalText()
    
    // 클립보드 비우기
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    
    // 리셋 알림 전송
    NotificationCenter.default.post(
        name: .voiceRecognitionReset,
        object: nil,
        userInfo: ["reason": "completeReset"]
    )
}
```

### 4. 세션 경계 감지 (연속 입력 모드)
```swift
// WakeWordDetector.swift:96-117
// 세션 경계 감지 조건
let isLengthBasedNewSession = !text.isEmpty && 
    text.count < Int(Double(lastSessionText.count) * 0.5)  // 50% 이상 줄어든 경우

if isLengthBasedNewSession && !lastSessionText.isEmpty {
    // 이전 세션 텍스트를 누적 버퍼에 추가
    accumulatedText += lastSessionText + " "
}
```

**감지 조건**:
- 텍스트 길이가 이전의 50% 미만으로 줄어듦
- 새로운 음성 인식 세션 시작으로 판단

---

## 실제 시나리오 예시

### 시나리오 1: 웨이크워드 → 명령 입력 → Enter
```
1. 사용자: "클로드" 발화
   → WakeWordDetector: 웨이크워드 감지
   → VoiceControlStateManager.handleWakeWordDetected()
   → completeReset(clearTextField: false) 실행
   → 음성 인식 재시작 (텍스트 필드 유지)

2. 사용자: "안녕하세요 오늘 날씨 어때요" 발화
   → 실시간 텍스트 스트리밍
   → Claude 앱에 증분 입력

3. 사용자: Enter 키 입력
   → VoiceControlStateManager.handleEnterKeyPressed()
   → completeReset(clearTextField: false) 실행
   → 음성 인식 재시작 (대화 컨텍스트 유지)
```

### 시나리오 2: 59초 자동 재시작
```
1. 00:00 - 음성 인식 시작
   → startListening() 호출
   → scheduleAutomaticRestart() - 59초 타이머 설정

2. 00:30 - 사용자 발화
   → "오늘 일정 확인해줘"
   → 정상 처리

3. 00:59 - 자동 재시작 트리거
   → performScheduledRestart() 실행
   → cleanupRecognitionTask()
   → 0.5초 대기
   → startAudioEngine() - 새 세션 시작
   → scheduleAutomaticRestart() - 다음 59초 타이머

4. 01:00 - 음성 인식 계속 (끊김 없음)
```

### 시나리오 3: 최종 전사 후 재시작
```
1. 사용자: "안녕하세요" 발화

2. 부분 전사 수신:
   → "안" (partial)
   → "안녕" (partial)
   → "안녕하세요" (partial)

3. 침묵 감지 (약 1-2초)
   → result.isFinal = true
   → recognizedText = "안녕하세요"

4. 재시작 지연 (사용자 설정: 0.5초)
   → DispatchQueue.asyncAfter

5. 재시작 실행:
   → stopListening()
   → 0.1초 대기
   → startListening()

6. 새 세션 준비 완료
```

### 시나리오 4: 에러 복구
```
1. 음성 인식 중 네트워크 에러 발생
   → Error code 203: Server error

2. 자동 복구 시도:
   → 1초 대기
   → stopListening()
   → startListening()

3. 복구 성공 시:
   → 음성 인식 재개
   → 사용자 개입 불필요

4. 복구 실패 시:
   → recognitionState = .idle
   → error = .audioEngineError
   → UI에 에러 표시
```

---

## 상태 플로우 다이어그램

### 1. Recognition State 전환
```
┌──────┐ startListening() ┌──────────┐
│ idle │─────────────────→│ starting │
└──────┘                   └──────────┘
    ↑                            │
    │                            ↓
    │                      ┌───────────┐
    │                      │ listening │←──┐
    │                      └───────────┘   │
    │                            │         │
    │                            ↓         │
    │                      ┌────────────┐  │
    │                      │ processing │──┘ (재시작)
    │                      └────────────┘
    │                            │
    │                            ↓
    │                       ┌──────────┐
    └───────────────────────│ stopping │
                            └──────────┘
```

### 2. 리셋 결정 트리
```
음성 인식 중
    │
    ├─ 59초 경과? → 예 → performScheduledRestart()
    │
    ├─ 최종 전사? → 예 → 지연 후 재시작
    │
    ├─ 웨이크워드 감지? → 예 → completeReset(clearTextField: false)
    │
    ├─ Enter 키? → 예 → completeReset(clearTextField: false)
    │
    ├─ 에러 발생? → 예 → 에러 코드 확인
    │                     │
    │                     ├─ 203 (서버) → 1초 후 재시작
    │                     └─ 기타 → 정지
    │
    └─ 계속 인식
```

### 3. completeReset 플로우
```
completeReset() 시작
    │
    ├─ 1. stopListening()
    │     ├─ 타이머 취소
    │     ├─ Recognition Task 정리
    │     └─ 상태 초기화
    │
    ├─ 2. clearAllTextBuffers()
    │     ├─ TextInputAutomator 리셋
    │     ├─ 클립보드 비우기
    │     └─ 리셋 알림 전송
    │
    ├─ 3. clearActiveAppTextField() [옵션]
    │     ├─ Cmd+A (전체 선택)
    │     └─ Backspace (삭제)
    │
    ├─ 4. 0.5초 대기
    │
    └─ 5. startListening()
          ├─ 권한 확인
          ├─ 오디오 엔진 시작
          └─ 59초 타이머 설정
```

---

## 주요 설정값

| 설정 | 값 | 설명 | 위치 |
|------|-----|------|------|
| maxContinuousTime | 59초 | Apple 60초 제한 회피 | VoiceRecognitionEngine.swift:34 |
| recognitionRestartDelay | 0.5초 (설정 가능) | 최종 전사 후 재시작 지연 | UserSettings.recognitionRestartDelay |
| requiresOnDeviceRecognition | true | 60초 제한 우회용 | VoiceRecognitionEngine.swift:73 |
| shouldReportPartialResults | true | 실시간 부분 전사 활성화 | VoiceRecognitionEngine.swift:301 |
| warningThreshold | 10초 | 타이머 경고 시점 | VoiceControlStateManager.swift:40 |

---

## 디버깅 팁

### 로그 확인 위치
```bash
# Xcode 콘솔에서 다음 키워드로 필터링:
🎤  # 음성 인식 관련
🔄  # 리셋/재시작 관련
⏰  # 타이머 관련
🎯  # 웨이크워드 관련
✅  # 성공
❌  # 실패
```

### 주요 체크포인트
1. 권한 상태: `PermissionManager.shared` 로그
2. 재시작 타이밍: `scheduleAutomaticRestart` 로그
3. 세션 경계: `isLengthBasedNewSession` 로그
4. 웨이크워드 매칭: `FuzzyMatching` 로그

### 문제 해결
- **음성 인식이 멈춤**: 59초 타이머 확인
- **텍스트가 누적됨**: `clearAllTextBuffers()` 호출 확인
- **웨이크워드 미감지**: `FuzzyMatching.threshold` 조정
- **재시작 실패**: 권한 상태 재확인