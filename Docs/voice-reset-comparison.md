# 음성 인식 리셋 프로세스 비교 분석
> 59초 타이머 만료 vs Enter 키 입력 시 실행 흐름 상세 비교

## 1. 59초 타이머 만료 시 리셋 프로세스

### 1.1 타이머 시작 및 카운트다운
```swift
// VoiceRecognitionEngine.swift:182
scheduleAutomaticRestart()
    ↓
// VoiceRecognitionEngine.swift:444-450
Timer.scheduledTimer(withTimeInterval: 59.0) → performScheduledRestart()
```

### 1.2 59초 경과 시 실행 순서

#### Step 1: VoiceRecognitionEngine.performScheduledRestart() [line 457-509]
```swift
// 1. 재시작 플래그 설정
isRestarting = true

// 2. 음성 인식 상태 변경
recognitionState = .stopping

// 3. 음성 인식 태스크 정리
cleanupRecognitionTask()
    - recognitionTask?.cancel()
    - recognitionRequest?.endAudio()
    - audioEngine.stop()
    - audioEngine.inputNode.removeTap(onBus: 0)
    - recognitionTask = nil
    - recognitionRequest = nil

// 4. 리셋 알림 전송 ⚠️ 중요
NotificationCenter.default.post(
    name: .voiceRecognitionReset,
    object: nil,
    userInfo: ["reason": "timerExpired", "clearTextField": true]
)

// 5. 대기 (0.4초)
await Task.sleep(nanoseconds: 400_000_000)

// 6. 음성 인식 재시작
recognitionState = .starting
try await startAudioEngine()
recognitionState = .listening
scheduleAutomaticRestart() // 다음 타이머 예약
```

#### Step 2: TextInputAutomator.handleVoiceRecognitionReset() [line 33-49]
```swift
// 알림 수신 처리
reason = "timerExpired"
clearTextField = true

// 1. 텍스트 버퍼 리셋
resetIncrementalText()
    - lastInputText = ""
    - currentAppBundleId = nil
    - lastInputTime = Date()

// 2. 텍스트 필드 클리어 (clearTextField가 true이므로)
await clearActiveAppTextField()
    - VoiceControlStateManager.shared.isPerformingTextFieldOperation = true
    - stopCountdownTimer()
    - await Task.sleep(0.1초)
    - 포커스된 텍스트 요소 찾기
    - AXUIElementSetAttributeValue로 빈 텍스트 설정
    - 또는 Command+A → Backspace
    - VoiceControlStateManager.shared.isPerformingTextFieldOperation = false
    - remainingTime = maxTime
    - startCountdownTimer()
```

### 1.3 59초 타이머 리셋 시 상태 변화
- ✅ `recognitionTask` 취소 및 정리
- ✅ `recognitionRequest` 종료 및 정리
- ✅ `audioEngine` 중지 및 탭 제거
- ✅ `lastInputText` 클리어
- ✅ `currentAppBundleId` 리셋
- ✅ 클립보드 클리어 ❌ (누락!)
- ✅ 활성 앱 텍스트 필드 클리어
- ✅ `remainingTime` 리셋
- ✅ 카운트다운 타이머 재시작
- ❌ `recognizedText` 클리어 안함
- ❌ `currentTranscription` 클리어 안함
- ❌ WakeWordDetector 상태 유지

---

## 2. Enter 키 입력 시 리셋 프로세스

### 2.1 Enter 키 감지
```swift
// KeyboardEventMonitor.swift:56-99
handleKeyEvent(event)
    ↓
// Enter 키 확인 (keyCode 36 or 76)
// resetOnEnterKey 설정 확인
// 대상 앱 확인
    ↓
NotificationCenter.default.post(name: .enterKeyPressed)
```

### 2.2 Enter 키 처리 실행 순서

#### Step 1: VoiceControlStateManager.handleEnterKeyPressed() [line 374-384]
```swift
// 알림 수신 및 처리
Task {
    await completeReset(clearTextField: true)
}
```

#### Step 2: VoiceControlStateManager.completeReset() [line 174-204]
```swift
// 1. 음성 인식 중지
stopListening()
    - isListening = false
    - voiceEngine?.stopListening()
        → VoiceRecognitionEngine.stopListening() [line 195-224]
            - recognitionState = .stopping
            - restartTimer?.invalidate()
            - cleanupRecognitionTask()
            - stopAudioLevelMonitoring()
            - voiceIsolationManager.cleanupAudioSession()
            - isListening = false
            - recognitionState = .idle
            - audioLevel = 0.0
            - isRestarting = false
    - stopCountdownTimer()
    - NotificationCenter.post(.voiceRecognitionReset, ["reason": "stopListening"])
    - NotificationCenter.post(.voiceControlStateChanged, ["isListening": false])

// 2. 모든 텍스트 버퍼 및 클립보드 클리어
await clearAllTextBuffers()
    - TextInputAutomator.shared.resetIncrementalText()
    - NSPasteboard.general.clearContents() ✅
    - NotificationCenter.post(.voiceRecognitionReset, ["reason": "completeReset"])

// 3. 활성 앱 텍스트 필드 클리어
await clearActiveAppTextField()
    - KeyboardSimulator.shared.selectAll()
    - await Task.sleep(0.1초)
    - KeyboardSimulator.shared.sendBackspace()

// 4. 대기 (0.5초)
await Task.sleep(nanoseconds: 500_000_000)

// 5. 음성 인식 재시작
try await startListening()
    - isListening = true
    - voiceEngine.startListening()
    - startCountdownTimer()
    - NotificationCenter.post(.voiceControlStateChanged, ["isListening": true])
```

### 2.3 Enter 키 리셋 시 상태 변화
- ✅ `recognitionTask` 취소 및 정리
- ✅ `recognitionRequest` 종료 및 정리
- ✅ `audioEngine` 중지 및 탭 제거
- ✅ `lastInputText` 클리어
- ✅ `currentAppBundleId` 리셋
- ✅ 클립보드 클리어 ✅
- ✅ 활성 앱 텍스트 필드 클리어
- ✅ `remainingTime` 리셋
- ✅ 카운트다운 타이머 재시작
- ❌ `recognizedText` 클리어 안함
- ❌ `currentTranscription` 클리어 안함
- ❌ WakeWordDetector 상태 유지

---

## 3. 주요 차이점 분석

### 3.1 실행 경로 차이

| 구분 | 59초 타이머 | Enter 키 |
|------|------------|----------|
| **시작점** | VoiceRecognitionEngine 내부 타이머 | KeyboardEventMonitor 외부 이벤트 |
| **주 처리 함수** | performScheduledRestart() | completeReset() |
| **음성 엔진 처리** | cleanupRecognitionTask()만 호출 | stopListening() 전체 호출 |
| **알림 전송** | 1회 (timerExpired) | 3회 (stopListening, completeReset, stateChanged) |
| **대기 시간** | 0.4초 | 0.5초 |
| **클립보드 처리** | ❌ 없음 | ✅ 클리어 |

### 3.2 리셋되는 구성 요소 비교

| 구성 요소 | 59초 타이머 | Enter 키 | 비고 |
|-----------|------------|----------|------|
| recognitionTask | ✅ | ✅ | |
| recognitionRequest | ✅ | ✅ | |
| audioEngine | ✅ | ✅ | |
| restartTimer | 유지 | ✅ 취소 | **차이** |
| lastInputText | ✅ | ✅ | |
| currentAppBundleId | ✅ | ✅ | |
| 클립보드 | ❌ | ✅ | **차이** |
| 텍스트 필드 | ✅ | ✅ | |
| recognizedText | ❌ | ❌ | 둘 다 유지 |
| currentTranscription | ❌ | ❌ | 둘 다 유지 |
| WakeWordDetector | 유지 | 유지 | |
| audioLevel | 유지 | ✅ 0으로 리셋 | **차이** |
| isRestarting 플래그 | 사용 | ✅ false로 리셋 | **차이** |

### 3.3 알림(Notification) 전송 차이

#### 59초 타이머
1. `voiceRecognitionReset` (reason: "timerExpired", clearTextField: true)

#### Enter 키
1. `voiceRecognitionReset` (reason: "stopListening")
2. `voiceControlStateChanged` (isListening: false)
3. `voiceRecognitionReset` (reason: "completeReset")
4. `voiceControlStateChanged` (isListening: true)

---

## 4. 문제점 및 개선 사항

### 4.1 발견된 불일치
1. **클립보드 처리**: 59초 타이머에서는 클립보드를 클리어하지 않음
2. **restartTimer 처리**: 59초 타이머는 자체 타이머이므로 유지, Enter는 외부에서 취소
3. **audioLevel 리셋**: Enter 키만 0으로 리셋
4. **알림 횟수**: Enter 키가 더 많은 알림 전송 (과도함)

### 4.2 권장 수정 사항

#### 옵션 1: 59초 타이머가 Enter 키와 동일한 `completeReset()` 사용
```swift
// VoiceRecognitionEngine.performScheduledRestart() 수정
private func performScheduledRestart() async {
    guard isListening && !isRestarting else { return }
    
    // VoiceControlStateManager의 completeReset 호출
    await VoiceControlStateManager.shared.completeReset(clearTextField: true)
}
```

#### 옵션 2: 두 프로세스를 독립적으로 유지하되 동일한 동작 보장
- 59초 타이머에 클립보드 클리어 추가
- recognizedText, currentTranscription 클리어 추가
- audioLevel 리셋 추가

### 4.3 현재 상태 요약
- **기본적인 리셋 기능은 둘 다 작동**하지만 세부 구현이 다름
- Enter 키가 더 철저한 리셋 수행 (클립보드 포함)
- 59초 타이머는 최소한의 리셋만 수행
- 사용자 입장에서는 **일관성 없는 동작**으로 느껴질 수 있음

---

## 5. 결론

현재 Enter 키 입력과 59초 타이머 만료 시의 리셋 프로세스는 **서로 다른 경로와 방식**으로 구현되어 있습니다:

1. **59초 타이머**: VoiceRecognitionEngine 내부에서 직접 처리, 최소 리셋
2. **Enter 키**: VoiceControlStateManager를 통한 완전한 리셋

**통일된 동작을 위해서는** 두 경우 모두 `VoiceControlStateManager.completeReset()`을 사용하도록 수정하는 것이 권장됩니다. 이렇게 하면:
- 코드 중복 제거
- 일관된 사용자 경험
- 유지보수 용이성 향상

---

*문서 작성일: 2025-08-29*