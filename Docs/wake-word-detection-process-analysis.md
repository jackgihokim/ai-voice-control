# 웨이크 워드 감지 후 프로세스 상세 분석

## 목차
1. [개요](#개요)
2. [전체 프로세스 플로우](#전체-프로세스-플로우)
3. [단계별 상세 분석](#단계별-상세-분석)
4. [타이머 메커니즘](#타이머-메커니즘)
5. [현재 구조의 문제점](#현재-구조의-문제점)
6. [실제 시나리오 예시](#실제-시나리오-예시)

## 개요

AI Voice Control 앱에서 웨이크 워드(예: "Claude", "클로드")가 감지된 후의 전체 프로세스를 분석합니다. 특히 10초 침묵 후 전체 리셋이 발생하는 메커니즘을 중점적으로 다룹니다.

### 주요 컴포넌트
- **VoiceRecognitionEngine**: 음성 인식 엔진
- **WakeWordDetector**: 웨이크 워드 감지 및 명령 버퍼 관리
- **VoiceControlStateManager**: 전체 상태 관리 및 타이머 제어
- **MenuBarViewModel**: UI 업데이트 및 앱 활성화

## 전체 프로세스 플로우

```
사용자가 "Claude"라고 말함
    ↓
[1] VoiceRecognitionEngine이 음성을 텍스트로 변환
    ↓
[2] WakeWordDetector가 텍스트에서 웨이크 워드 감지
    ↓
[3] WakeWordDetector 상태가 'wakeWordDetected'로 변경
    ↓
[4] 'wakeWordDetected' 알림 전송
    ↓
[5] VoiceControlStateManager가 completeReset() 호출
    ↓
[6] MenuBarViewModel이 해당 앱 활성화
    ↓
[7] 사용자가 명령을 말하기 시작
    ↓
[8-A] 계속 말하는 경우: 타이머 연장
[8-B] 10초 침묵: 타임아웃 → 전체 리셋
```

## 단계별 상세 분석

### 1단계: 음성 인식 및 텍스트 변환

**파일**: `VoiceRecognitionEngine.swift:330-334`

```swift
recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
    Task { @MainActor in
        self?.handleRecognitionResult(result: result, error: error)
    }
}
```

음성이 텍스트로 변환되면 `handleRecognitionResult`가 호출됩니다.

### 2단계: 웨이크 워드 감지

**파일**: `VoiceRecognitionEngine.swift:373`

```swift
wakeWordDetector.processTranscription(transcription, apps: userSettings.registeredApps)
```

변환된 텍스트가 WakeWordDetector로 전달됩니다.

### 3단계: WakeWordDetector 처리

**파일**: `WakeWordDetector.swift:71-88`

```swift
func processTranscription(_ text: String, apps: [AppConfiguration]) {
    let lowercasedText = text.lowercased()
    
    switch state {
    case .idle:
        if let app = detectWakeWord(in: lowercasedText, apps: apps) {
            #if DEBUG
            print("🎯 Wake word detected in IDLE state: \(app.name)")
            #endif
            handleWakeWordDetection(app: app)
        }
    // ... 다른 상태 처리
    }
}
```

### 4단계: 웨이크 워드 처리 시작

**파일**: `WakeWordDetector.swift:276-311`

```swift
private func handleWakeWordDetection(app: AppConfiguration) {
    // 이전 타이머가 있다면 정리
    wakeWordTimer?.invalidate()
    wakeWordTimer = nil
    
    // 상태 변경
    state = .wakeWordDetected(app: app)
    detectedApp = app
    isWaitingForCommand = true
    commandBuffer = ""
    
    // 텍스트 누적 초기화
    accumulatedText = ""
    lastSessionText = ""
    isAccumulatingText = true
    lastTextUpdateTime = Date()
    
    // 중요: 타이머 시작이 주석 처리됨 (line 297-298)
    // startCommandTimer() - REMOVED: 10초 타이머가 음성인식 리셋과 충돌
    
    // 웨이크 워드 감지 알림 전송
    NotificationCenter.default.post(
        name: .wakeWordDetected,
        object: nil,
        userInfo: ["app": app]
    )
}
```

### 5단계: VoiceControlStateManager의 반응

**파일**: `VoiceControlStateManager.swift:341-352`

```swift
@objc private func handleWakeWordDetected(_ notification: Notification) {
    #if DEBUG
    if let app = notification.userInfo?["app"] as? AppConfiguration {
        print("🎯 Wake word detected for \(app.name) - performing complete reset")
    }
    #endif
    
    Task {
        // 웨이크워드 감지 시 음성인식 완전 리셋 (텍스트 필드는 유지)
        await completeReset(clearTextField: false)
    }
}
```

### 6단계: Complete Reset 실행

**파일**: `VoiceControlStateManager.swift:170-200`

```swift
func completeReset(clearTextField: Bool = true) async {
    #if DEBUG
    print("🔄 StateManager: Starting complete reset (clearTextField: \(clearTextField))")
    #endif
    
    // 1. 음성인식 중지
    stopListening()
    
    // 2. 모든 텍스트 버퍼와 클립보드 지우기
    await clearAllTextBuffers()
    
    // 3. 활성 앱의 텍스트 필드 지우기 (옵션)
    if clearTextField {
        await clearActiveAppTextField()
    }
    
    // 4. 0.5초 대기
    try? await Task.sleep(nanoseconds: 500_000_000)
    
    // 5. 음성인식 재시작
    do {
        try await startListening()
        #if DEBUG
        print("✅ Complete reset successful - voice recognition restarted")
        #endif
    } catch {
        #if DEBUG
        print("❌ Failed to restart voice recognition: \(error)")
        #endif
    }
}
```

### 7단계: 명령 입력 처리

**파일**: `WakeWordDetector.swift:90-157`

사용자가 명령을 말하기 시작하면:

```swift
case .wakeWordDetected(let app):
    // 현재 텍스트를 추적
    lastSessionText = text
    
    // 누적된 텍스트와 현재 텍스트를 결합
    let combinedText = userSettings.continuousInputMode ? (accumulatedText + text) : text
    commandBuffer = combinedText
    
    // 음성 입력이 있으면 명령 타이머를 연장
    if !text.isEmpty {
        startCommandTimer()  // 타이머 재시작으로 시간 연장
        #if DEBUG
        print("⏱️ Command timer extended due to voice input")
        #endif
    }
    
    // 실시간 텍스트 스트리밍을 위한 알림 전송
    NotificationCenter.default.post(
        name: .commandBufferUpdated,
        object: nil,
        userInfo: ["app": app, "text": combinedText]
    )
```

## 타이머 메커니즘

### 10초 침묵 타이머 (WakeWordDetector)

**파일**: `WakeWordDetector.swift:10-13, 349-356`

```swift
private var commandTimeout: TimeInterval {
    // 고정값 10초 사용
    return 10.0
}

private func startCommandTimer() {
    wakeWordTimer?.invalidate()
    wakeWordTimer = Timer.scheduledTimer(
        withTimeInterval: commandTimeout,  // 10초
        repeats: false
    ) { _ in
        Task { @MainActor in
            self.handleTimeout()
        }
    }
}
```

### 타임아웃 처리

**파일**: `WakeWordDetector.swift:358-380`

```swift
private func handleTimeout() {
    #if DEBUG
    print("⏱️ Command timeout - performing complete reset")
    print("   Current state: \(state)")
    print("   Accumulated text: '\(accumulatedText)'")
    print("   Last session text: '\(lastSessionText)'")
    #endif
    
    // 타임아웃 알림 전송
    NotificationCenter.default.post(
        name: .commandTimeout,
        object: nil,
        userInfo: ["reason": "silenceTimeout"]
    )
    
    // 로컬 상태 리셋
    resetState()
    
    // VoiceControlStateManager를 통한 전체 시스템 리셋
    Task {
        await VoiceControlStateManager.shared.completeReset()
    }
}
```

### 59초 카운트다운 타이머 (VoiceControlStateManager)

**파일**: `VoiceControlStateManager.swift:257-285`

```swift
private func startCountdownTimer() {
    stopCountdownTimer()
    remainingTime = maxTime  // 59초
    
    countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            self.remainingTime -= 1
            
            // 10초 남았을 때 경고
            if self.remainingTime == self.warningThreshold {
                self.showWarning()
            }
            
            // 시간 만료 시 자동 재시작
            if self.remainingTime <= 0 {
                self.remainingTime = self.maxTime
            }
        }
    }
}
```

### 59초 자동 재시작 타이머 (VoiceRecognitionEngine)

**파일**: `VoiceRecognitionEngine.swift:419-430`

```swift
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

## 현재 구조의 문제점

### 1. 이중 리셋 문제

웨이크 워드가 감지되면:
1. 즉시 `VoiceControlStateManager.completeReset()`이 호출됨
2. 10초 후 침묵 타임아웃 시 다시 `completeReset()`이 호출됨

### 2. 타이머 시작 누락

`WakeWordDetector.handleWakeWordDetection()`에서:
```swift
// 타이머 제거 - VoiceControlStateManager가 completeReset으로 관리
// startCommandTimer() - REMOVED: 10초 타이머가 음성인식 리셋과 충돌
```
주석 처리되어 있어 10초 타이머가 시작되지 않아야 하지만, 실제로는 명령 입력 중 (`case .wakeWordDetected`) 타이머가 시작됨.

### 3. 타이머 관리 혼란

3개의 독립적인 타이머가 동시에 작동:
- WakeWordDetector: 10초 침묵 타이머
- VoiceControlStateManager: 59초 카운트다운 (UI 표시용)
- VoiceRecognitionEngine: 59초 자동 재시작 (Apple 제한 회피)

### 4. 상태 불일치

웨이크 워드 감지 → completeReset 호출 → 음성인식 재시작
- WakeWordDetector는 여전히 `wakeWordDetected` 상태
- VoiceRecognitionEngine은 새로운 세션 시작
- 상태 동기화 문제 발생 가능

## 실제 시나리오 예시

### 시나리오 1: 정상적인 명령 입력

```
시간    | 사용자 행동              | 시스템 반응
--------|------------------------|------------------------------------------
0초     | "Claude" 말함           | 웨이크 워드 감지 → completeReset → 음성인식 재시작
0.5초   |                        | Claude 앱 활성화
1초     | "오늘 날씨 어때?" 시작    | 타이머 시작 (10초)
3초     | 말하기 계속             | 타이머 연장 (다시 10초)
5초     | 말하기 완료             | 명령 버퍼에 전체 텍스트 저장
15초    | 10초 침묵               | 타임아웃 → completeReset → 음성인식 재시작
```

### 시나리오 2: 긴 명령 입력 중 침묵

```
시간    | 사용자 행동              | 시스템 반응
--------|------------------------|------------------------------------------
0초     | "Claude" 말함           | 웨이크 워드 감지 → completeReset
1초     | "이메일 작성해줘" 말함    | 타이머 시작 (10초)
3초     | (생각 중... 침묵)        | 타이머 계속 진행
13초    | (아직 생각 중)          | 타임아웃! → 전체 리셋
14초    | "제목은..." 말하려고 함   | 이미 리셋됨, 새로운 세션 시작
```

### 시나리오 3: 연속 입력 모드

```
시간    | 사용자 행동              | 시스템 반응
--------|------------------------|------------------------------------------
0초     | "Claude" 말함           | 웨이크 워드 감지
1초     | "첫 번째 문장" 말함      | 텍스트 누적 시작
3초     | (잠시 침묵)             | 세션 경계 감지
4초     | "두 번째 문장" 말함      | 이전 텍스트와 결합
14초    | 10초 침묵               | 타임아웃 → 모든 누적 텍스트 손실
```

## 개선이 필요한 부분

1. **웨이크 워드 감지 시 즉시 리셋 제거**
   - completeReset 대신 타이머만 리셋

2. **10초 타이머 로직 개선**
   - 음성 입력이 있을 때마다 타이머 연장
   - 실제 침묵이 10초 지속될 때만 타임아웃

3. **타이머 역할 명확화**
   - 각 타이머의 목적과 트리거 조건 명확히 구분
   - 중복 제거 및 통합 관리

4. **상태 동기화**
   - WakeWordDetector와 VoiceRecognitionEngine 상태 일치
   - 리셋 시 모든 컴포넌트 상태 동기화

## 결론

현재 시스템은 웨이크 워드 감지 후 사용자가 명령을 말하는 도중 10초 침묵이 발생하면 전체 시스템이 리셋되는 문제가 있습니다. 이는 사용자 경험을 크게 해치며, 특히 긴 명령이나 복잡한 요청을 할 때 문제가 됩니다.

주요 원인은:
1. 웨이크 워드 감지 시 즉시 completeReset 호출
2. 10초 침묵 타이머의 부적절한 관리
3. 여러 타이머 간의 충돌과 중복

이를 해결하려면 타이머 관리를 단순화하고, 웨이크 워드 감지 후 프로세스를 재설계해야 합니다.