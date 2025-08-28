# 텍스트 버퍼 리셋 메커니즘 분석

## 목차
1. [개요](#개요)
2. [텍스트 버퍼 종류와 위치](#텍스트-버퍼-종류와-위치)
3. [리셋 메커니즘 상세 분석](#리셋-메커니즘-상세-분석)
4. [리셋 알림 체계](#리셋-알림-체계)
5. [현재 문제점](#현재-문제점)
6. [리셋 플로우 다이어그램](#리셋-플로우-다이어그램)
7. [개선 제안](#개선-제안)

---

## 개요

AI Voice Control 앱의 음성 인식 시스템은 여러 개의 텍스트 버퍼를 관리합니다. 이 버퍼들은 음성 인식 세션이 리셋될 때 적절히 초기화되어야 하지만, 현재 일부 버퍼가 제대로 초기화되지 않는 문제가 있습니다.

### 리셋이 필요한 시점
- 웨이크워드 감지 시
- Enter 키 입력 시
- 59초 자동 재시작 시
- 에러 발생 시
- 사용자가 Stop/Start 버튼 클릭 시

---

## 텍스트 버퍼 종류와 위치

### 1. VoiceRecognitionEngine (`VoiceRecognitionEngine.swift`)

```swift
// 줄 13-14
@Published var recognizedText = ""      // 최종 인식된 텍스트
@Published var currentTranscription = "" // 현재 진행중인 전사
```

**역할**: 
- `recognizedText`: isFinal이 true일 때 저장되는 최종 텍스트
- `currentTranscription`: 실시간으로 업데이트되는 부분 전사 텍스트

**리셋 위치**:
- `currentTranscription`: 줄 427에서 isFinal 시 초기화
- `recognizedText`: **초기화 코드 없음** ⚠️

### 2. WakeWordDetector (`WakeWordDetector.swift`)

```swift
// 줄 7, 10-11
@Published var commandBuffer = ""  // 웨이크워드 감지 후 명령 버퍼
private var accumulatedText = ""   // 세션 간 누적 텍스트
private var lastSessionText = ""   // 이전 세션 텍스트
```

**역할**:
- `commandBuffer`: 웨이크워드 감지 후 사용자 명령 저장
- `accumulatedText`: 연속 입력 모드에서 세션 간 텍스트 누적
- `lastSessionText`: 세션 경계 감지용

**리셋 함수**: `resetState()` (줄 326-348)
```swift
func resetState() {
    state = .idle
    isWaitingForCommand = false
    detectedApp = nil
    commandBuffer = ""
    
    // 텍스트 누적 상태 리셋
    accumulatedText = ""
    lastSessionText = ""
    isAccumulatingText = false
    lastTextUpdateTime = Date()
}
```

### 3. MenuBarViewModel (`MenuBarViewModel.swift`)

```swift
// 줄 16
@Published var transcribedText: String = ""  // UI에 표시되는 텍스트
```

**역할**: 메뉴바 UI에 표시되는 전사 텍스트

**리셋 위치**:
- 줄 79: `clearTranscription()` 함수
- 줄 457: `handleVoiceRecognitionReset()` 함수

### 4. TextInputAutomator (`TextInputAutomator.swift`)

```swift
// 줄 46-48
private var lastInputText: String = ""        // 마지막 입력 텍스트
private var currentAppBundleId: String?       // 현재 앱 ID
private var lastInputTime: Date = Date()      // 마지막 입력 시간
```

**역할**: 증분 텍스트 입력을 위한 상태 추적

**리셋 함수**: `resetIncrementalText()` (줄 232-240)
```swift
func resetIncrementalText() {
    lastInputText = ""
    currentAppBundleId = nil
    lastInputTime = Date()
    
    #if DEBUG
    print("🔄 Incremental text tracking reset")
    #endif
}
```

### 5. 시스템 클립보드

**위치**: 
- `VoiceControlStateManager.swift` 줄 215-216
- `TextInputAutomator.swift` 줄 524, 535
- `MenuBarView.swift` 줄 337

**리셋 코드**:
```swift
let pasteboard = NSPasteboard.general
pasteboard.clearContents()
```

---

## 리셋 메커니즘 상세 분석

### 1. VoiceControlStateManager의 중앙 리셋 (`VoiceControlStateManager.swift`)

#### `completeReset()` 함수 (줄 170-200)
```swift
func completeReset(clearTextField: Bool = true) async {
    // 1. 음성 인식 정지
    stopListening()
    
    // 2. 모든 텍스트 버퍼와 클립보드 정리
    await clearAllTextBuffers()
    
    // 3. 활성 앱의 텍스트 필드 정리 (선택적)
    if clearTextField {
        await clearActiveAppTextField()
    }
    
    // 4. 0.5초 대기
    try? await Task.sleep(nanoseconds: 500_000_000)
    
    // 5. 음성 인식 재시작
    try await startListening()
}
```

#### `clearAllTextBuffers()` 함수 (줄 203-224)
```swift
private func clearAllTextBuffers() async {
    // WakeWordDetector 상태는 유지 (주석 처리됨) ⚠️
    // voiceEngine?.resetWakeWordState() <- 제거됨
    
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

### 2. 리셋 트리거 포인트

#### 웨이크워드 감지 시 (줄 341-352)
```swift
@objc private func handleWakeWordDetected(_ notification: Notification) {
    Task {
        // 웨이크워드 감지 시 음성인식 완전 리셋 (텍스트 필드는 유지)
        await completeReset(clearTextField: false)
    }
}
```

#### Enter 키 입력 시 (줄 354-364)
```swift
@objc private func handleEnterKeyPressed(_ notification: Notification) {
    Task {
        // Enter 키의 경우 텍스트 필드는 지우지 않음
        await completeReset(clearTextField: false)
    }
}
```

---

## 리셋 알림 체계

### 알림 이름
```swift
extension Notification.Name {
    static let voiceRecognitionReset = Notification.Name("voiceRecognitionReset")
}
```

### 알림 구독자와 처리

#### 1. WakeWordDetector (줄 45-63)
```swift
@objc private func handleVoiceRecognitionReset(_ notification: Notification) {
    let reason = notification.userInfo?["reason"] as? String ?? "unknown"
    
    // 웨이크워드 처리 중에는 리셋 무시 ⚠️
    switch state {
    case .wakeWordDetected, .waitingForCommand:
        print("⚠️ Ignoring reset - currently processing wake word command")
        return
    default:
        resetState()
    }
}
```

#### 2. MenuBarViewModel (줄 448-464)
```swift
@objc private func handleVoiceRecognitionReset(_ notification: Notification) {
    // 전사 텍스트 초기화
    transcribedText = ""
    
    // 상태 메시지 리셋
    statusMessage = "Ready"
}
```

#### 3. TextInputAutomator (줄 33-41)
```swift
@objc private func handleVoiceRecognitionReset(_ notification: Notification) {
    resetIncrementalText()
}
```

---

## 현재 문제점

### 1. VoiceRecognitionEngine 텍스트 미초기화 ❌

**문제**: `stopListening()` 함수에서 텍스트 버퍼를 초기화하지 않음

```swift
// VoiceRecognitionEngine.swift 줄 195-223
func stopListening() {
    guard recognitionState == .listening else { return }
    
    recognitionState = .stopping
    
    // 타이머, 태스크 정리 등...
    
    isListening = false
    recognitionState = .idle
    audioLevel = 0.0
    isRestarting = false
    
    // ⚠️ recognizedText와 currentTranscription 초기화 누락!
}
```

**영향**: 
- 이전 세션의 텍스트가 새 세션에 남아있음
- UI에 이전 텍스트가 계속 표시될 수 있음

### 2. WakeWordDetector 리셋 거부 ⚠️

**문제**: 웨이크워드 감지 상태에서는 리셋 알림을 무시

```swift
case .wakeWordDetected, .waitingForCommand:
    print("⚠️ Ignoring reset - currently processing wake word command")
    return
```

**영향**:
- 다른 컴포넌트는 리셋되는데 WakeWordDetector만 리셋 안 됨
- 상태 불일치 발생

### 3. 클립보드 무조건 초기화 🗑️

**문제**: 리셋 시 항상 클립보드를 비움

```swift
let pasteboard = NSPasteboard.general
pasteboard.clearContents()  // 사용자의 클립보드 내용 손실!
```

**영향**:
- 사용자가 복사해둔 내용이 사라짐
- 다른 앱 작업에 영향

### 4. 리셋 시점 불일치 ⏱️

**문제**: 컴포넌트마다 리셋 타이밍이 다름
- VoiceControlStateManager: 즉시 리셋
- WakeWordDetector: 조건부 리셋
- MenuBarViewModel: 알림 수신 시 리셋

---

## 리셋 플로우 다이어그램

### 정상 플로우
```
사용자 액션 (웨이크워드/Enter/Stop)
    ↓
VoiceControlStateManager.completeReset()
    ↓
    ├─ stopListening()
    │   └─ [문제] 텍스트 초기화 안 함 ❌
    │
    ├─ clearAllTextBuffers()
    │   ├─ TextInputAutomator.resetIncrementalText() ✅
    │   ├─ 클립보드 비우기 ⚠️
    │   └─ voiceRecognitionReset 알림 전송
    │       ├─ WakeWordDetector [조건부 처리] ⚠️
    │       ├─ MenuBarViewModel [처리] ✅
    │       └─ TextInputAutomator [처리] ✅
    │
    ├─ clearActiveAppTextField() [선택적]
    │
    └─ startListening()
```

### 문제 시나리오
```
웨이크워드 "클로드" 감지
    ↓
WakeWordDetector 상태: .wakeWordDetected
    ↓
completeReset() 실행
    ↓
voiceRecognitionReset 알림 전송
    ↓
WakeWordDetector: "리셋 무시!" ⚠️
    ↓
결과: 
- VoiceRecognitionEngine.recognizedText = "이전 텍스트" (초기화 안 됨)
- WakeWordDetector.commandBuffer = "이전 명령" (리셋 거부됨)
- MenuBarViewModel.transcribedText = "" (정상 초기화)
- TextInputAutomator.lastInputText = "" (정상 초기화)
```

---

## 개선 제안

### 1. VoiceRecognitionEngine 수정

```swift
func stopListening() {
    guard recognitionState == .listening else { return }
    
    recognitionState = .stopping
    
    // 기존 정리 코드...
    
    // 텍스트 버퍼 초기화 추가
    recognizedText = ""
    currentTranscription = ""
    
    // WakeWordDetector 리셋 추가
    wakeWordDetector.resetState()
    
    isListening = false
    recognitionState = .idle
    audioLevel = 0.0
    isRestarting = false
}
```

### 2. WakeWordDetector 수정

```swift
@objc private func handleVoiceRecognitionReset(_ notification: Notification) {
    let reason = notification.userInfo?["reason"] as? String ?? "unknown"
    
    // completeReset인 경우 무조건 리셋
    if reason == "completeReset" {
        resetState()
        return
    }
    
    // 다른 경우는 기존 로직 유지
    switch state {
    case .wakeWordDetected, .waitingForCommand:
        // stopListening 등 일부 경우만 무시
        if reason == "stopListening" {
            return
        }
        resetState()
    default:
        resetState()
    }
}
```

### 3. 클립보드 관리 개선

```swift
private func clearAllTextBuffers(clearClipboard: Bool = false) async {
    // TextInputAutomator 리셋
    TextInputAutomator.shared.resetIncrementalText()
    
    // 클립보드는 선택적으로만 비우기
    if clearClipboard {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
    }
    
    // 리셋 알림 전송
    NotificationCenter.default.post(
        name: .voiceRecognitionReset,
        object: nil,
        userInfo: ["reason": "completeReset"]
    )
}
```

### 4. 통합 리셋 함수 추가

```swift
// VoiceRecognitionEngine에 추가
func resetAllTextBuffers() {
    recognizedText = ""
    currentTranscription = ""
    wakeWordDetector.resetState()
    
    #if DEBUG
    print("🧹 VoiceRecognitionEngine: All text buffers reset")
    #endif
}
```

---

## 테스트 체크리스트

리셋 기능 수정 후 다음 항목들을 테스트:

- [ ] 웨이크워드 감지 후 리셋 시 모든 버퍼 초기화 확인
- [ ] Enter 키 입력 후 텍스트 필드 상태 확인
- [ ] 59초 자동 재시작 시 버퍼 상태 확인
- [ ] 클립보드 내용 보존 여부 확인
- [ ] 연속 발화 시 텍스트 누적 정상 동작 확인
- [ ] Stop → Start 시 이전 텍스트 남아있지 않은지 확인

---

## 결론

현재 음성 인식 시스템의 텍스트 버퍼 리셋은 불완전하고 일관성이 없습니다. 주요 문제는:

1. **VoiceRecognitionEngine**에서 텍스트를 초기화하지 않음
2. **WakeWordDetector**가 특정 상황에서 리셋을 거부함
3. **클립보드**를 무조건 비워서 사용자 경험 저하
4. 컴포넌트 간 **리셋 타이밍 불일치**

이러한 문제들을 해결하려면 각 컴포넌트의 리셋 로직을 수정하고, 통합된 리셋 메커니즘을 구현해야 합니다.