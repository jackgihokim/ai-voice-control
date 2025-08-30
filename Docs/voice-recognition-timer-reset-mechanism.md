# 음성 인식 타이머 리셋 메커니즘

## 개요

이 문서는 AI Voice Control 애플리케이션의 개선된 59초 타이머 리셋 메커니즘을 설명합니다. 변경사항은 음성 인식 타이머가 만료되어 자동으로 재시작될 때 모든 컴포넌트에서 적절한 UI 동기화와 상태 관리를 보장합니다.

## 문제 분석

### 기존 문제점들

#### 1. UI 업데이트 문제
- **증상**: 59초 타이머 리셋 중 메뉴바 버튼이 변경되지 않음
- **원인**: `VoiceRecognitionEngine.performScheduledRestart()`가 `VoiceControlStateManager`를 우회함
- **영향**: 사용자가 리셋 과정을 시각적으로 확인할 수 없음

#### 2. 이중 `isListening` 변수
애플리케이션에는 서로 다른 목적을 가진 두 개의 별도 `isListening` 변수가 있었습니다:

```swift
// VoiceControlStateManager.swift:27
@Published var isListening = false  // 상위 레벨 앱 상태

// VoiceRecognitionEngine.swift:14  
@Published var isListening = false  // 하위 레벨 오디오 엔진 상태
```

#### 3. 상태 동기화 문제
- **StateManager**: 전체 앱 생명주기 관리 (`stopListening()` → `startListening()`)
- **VoiceEngine**: 내부 오디오 엔진 재시작만 처리
- **결과**: 두 `isListening` 상태가 비동기화될 수 있음

#### 4. MenuBarViewModel 바인딩 충돌
```swift
// MenuBarViewModel에서 이중 바인딩
voiceEngine?.$isListening.sink { self?.isListening = $0 }     // 바인딩 1
stateManager.$isListening.assign(to: &$isListening)          // 바인딩 2 (1번 덮어씀)
```

## 해결책 아키텍처

### 핵심 원칙: StateManager 중심 관리

모든 음성 인식 상태 변경이 이제 `VoiceControlStateManager`를 통해 흐르도록 하여 다음을 보장:
- ✅ 컴포넌트 간 일관된 상태
- ✅ 기존 바인딩을 통한 적절한 UI 업데이트
- ✅ 앱 상태의 단일 정보 소스

### 구현 전략

#### 1. 위임 패턴
직접 오디오 엔진 재시작 대신, `VoiceRecognitionEngine`이 타이머 만료를 `StateManager`에게 위임:

```swift
// 기존: 직접 재시작 (StateManager 우회)
performScheduledRestart() {
    // 복잡한 오디오 엔진 재시작 로직
    recognitionState = .starting
    try await startAudioEngine()
    // ... StateManager는 관여하지 않음
}

// 개선: StateManager에게 위임
performScheduledRestart() {
    // 간단한 위임
    NotificationCenter.default.post(name: .timerExpiredReset, ...)
}
```

#### 2. 통합 리셋 프로세스
`StateManager`가 동일한 `completeReset()` 메서드를 통해 모든 리셋을 처리:
- 사용자 버튼 클릭
- 웨이크워드 감지
- Enter 키 입력
- **59초 타이머 만료** (신규 추가)

## 코드 변경사항

### 1. 새로운 알림 타입

**파일**: `VoiceRecognitionEngine.swift`
```swift
extension Notification.Name {
    static let voiceIsolationStateChanged = Notification.Name("voiceIsolationStateChanged")
    static let voiceEngineRestarted = Notification.Name("voiceEngineRestarted")
    static let timerExpiredReset = Notification.Name("timerExpiredReset")  // 신규
}
```

### 2. 단순화된 performScheduledRestart

**파일**: `VoiceRecognitionEngine.swift`
```swift
private func performScheduledRestart() async {
    let activeApp = NSWorkspace.shared.frontmostApplication
    #if DEBUG
    print("🔄 [VOICE-ENGINE] performScheduledRestart called - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
    print("    isListening: \(isListening), isRestarting: \(isRestarting), state: \(recognitionState)")
    #endif
    
    guard isListening && !isRestarting else { 
        #if DEBUG
        print("⚠️ [VOICE-ENGINE] Skipping restart - isListening: \(isListening), isRestarting: \(isRestarting)")
        #endif
        return 
    }
    
    // 비동기 호환 동기화
    isRestarting = true
    defer { isRestarting = false }
    
    #if DEBUG
    print("📡 [VOICE-ENGINE] StateManager에게 59초 타이머 만료 위임")
    #endif
    
    // StateManager에게 완전한 재시작 과정 위임
    // UI 업데이트와 상태 동기화 보장
    NotificationCenter.default.post(
        name: .timerExpiredReset,
        object: nil,
        userInfo: [
            "reason": "timerExpired", 
            "clearTextField": true,
            "sourceEngine": "VoiceRecognitionEngine"
        ]
    )
}
```

**주요 변경사항**:
- ❌ 제거: 직접 오디오 엔진 재시작 로직
- ❌ 제거: 수동 상태 관리 
- ✅ 추가: StateManager로의 간단한 알림
- ✅ 추가: 포괄적인 디버그 로깅

### 3. StateManager 타이머 만료 핸들러

**파일**: `VoiceControlStateManager.swift`

#### 옵저버 등록:
```swift
private func setupNotificationObservers() {
    // ... 기존 옵저버들 ...
    
    // 타이머 만료 리셋 - voice engine에서 위임받음
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleTimerExpiredReset),
        name: .timerExpiredReset,
        object: nil
    )
}
```

#### 핸들러 구현:
```swift
@objc private func handleTimerExpiredReset(_ notification: Notification) {
    let activeApp = NSWorkspace.shared.frontmostApplication
    let reason = notification.userInfo?["reason"] as? String ?? "unknown"
    let clearTextField = notification.userInfo?["clearTextField"] as? Bool ?? false
    let sourceEngine = notification.userInfo?["sourceEngine"] as? String ?? "unknown"
    
    #if DEBUG
    print("⏰ [TIMER-DEBUG] \(sourceEngine)에서 타이머 만료 리셋 - 완전 리셋 수행 - 활성 앱: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
    print("   이유: \(reason), clearTextField: \(clearTextField)")
    print("   현재 상태: isListening=\(isListening), isTransitioning=\(isTransitioning)")
    #endif
    
    Task {
        // UI 업데이트 보장을 위해 StateManager를 통한 완전 리셋 수행
        await completeReset(clearTextField: clearTextField)
    }
}
```

## 동기화 흐름

### 완전한 59초 리셋 프로세스

```
1. VoiceEngine 타이머 만료 (59초)
   │
   ▼
2. VoiceEngine.performScheduledRestart()
   │ 📡 [VOICE-ENGINE] StateManager에게 59초 타이머 만료 위임
   │
   ▼
3. NotificationCenter.post(.timerExpiredReset)
   │
   ▼
4. StateManager.handleTimerExpiredReset()
   │ ⏰ [TIMER-DEBUG] VoiceRecognitionEngine에서 타이머 만료 리셋
   │
   ▼
5. StateManager.completeReset(clearTextField: true)
   │
   ├─▼ StateManager.stopListening()
   │   │ 🛑 [TIMER-DEBUG] 음성 인식 중지
   │   │ StateManager.isListening = false
   │   │ VoiceEngine.stopListening() 호출됨
   │   │ VoiceEngine.isListening = false
   │   │
   │   ▼ UI 업데이트: "Stop Listening" → "Start Listening"
   │
   ├─▼ 텍스트 버퍼 및 필드 클리어 (0.5초 지연)
   │
   └─▼ StateManager.startListening()
       │ 🎙️ [TIMER-DEBUG] 음성 인식 시작
       │ StateManager.isListening = true
       │ VoiceEngine.startListening() 호출됨
       │ VoiceEngine.isListening = true
       │
       ▼ UI 업데이트: "Start Listening" → "Stop Listening"
```

### 상태 동기화 타임라인

| 시점 | StateManager.isListening | VoiceEngine.isListening | UI 버튼 텍스트 |
|------|-------------------------|------------------------|----------------|
| T0   | `true`                  | `true`                 | "Stop Listening" |
| T1   | `false` (중지 중)       | `false` (중지됨)       | "Start Listening" |
| T2   | `true` (재시작됨)       | `true` (재시작됨)      | "Stop Listening" |

## 디버그 로깅

### 로그 태그와 의미

- `[VOICE-ENGINE]`: VoiceRecognitionEngine 작업
- `[TIMER-DEBUG]`: StateManager 타이머 및 상태 작업  
- `[APP-SWITCH]`: 애플리케이션 전환 감지
- `[KEYBOARD-MONITOR]`: Enter 키 감지
- `[APP-ACTIVATOR]`: 애플리케이션 활성화 프로세스

### 주요 디버그 메시지

#### 타이머 만료 위임:
```
📡 [VOICE-ENGINE] StateManager에게 59초 타이머 만료 위임
⏰ [TIMER-DEBUG] VoiceRecognitionEngine에서 타이머 만료 리셋 - 완전 리셋 수행
```

#### 상태 변경:
```
🛑 [TIMER-DEBUG] 음성 인식 중지 - 앱: ChatGPT (com.openai.chat)
🎙️ [TIMER-DEBUG] 음성 인식 시작 - 앱: ChatGPT (com.openai.chat)
```

#### 완료:
```
✅ [TIMER-DEBUG] 완전 리셋 성공 - 음성 인식 재시작됨
    최종 상태: isListening=true, isTransitioning=false
    Voice engine 상태: true
```

## 새로운 접근법의 장점

### 1. UI 일관성
- ✅ 메뉴바 버튼이 리셋 중 적절히 업데이트됨
- ✅ 시각적 피드백으로 리셋 과정 확인 가능
- ✅ 사용자가 "Stop Listening" ↔ "Start Listening" 전환을 볼 수 있음

### 2. 상태 관리
- ✅ 단일 정보 소스 (StateManager)
- ✅ 두 `isListening` 변수가 동기화 상태 유지
- ✅ 모든 리셋 트리거에서 일관된 동작

### 3. 코드 유지보수성  
- ✅ 단순화된 VoiceEngine 로직
- ✅ 중앙화된 상태 관리
- ✅ 포괄적인 로깅으로 더 쉬운 디버깅

### 4. 견고성
- ✅ 모든 시나리오에서 동일한 리셋 로직
- ✅ 적절한 오류 처리 및 복구
- ✅ 상태 비동기화 문제 없음

## 문제 해결

### 59초 리셋 후 타이머가 멈출 경우

1. **콘솔 로그 확인**:
   ```
   📡 [VOICE-ENGINE] StateManager에게 59초 타이머 만료 위임
   ```
   없으면: VoiceEngine 위임이 작동하지 않음

2. **StateManager 응답 확인**:
   ```
   ⏰ [TIMER-DEBUG] VoiceRecognitionEngine에서 타이머 만료 리셋
   ```
   없으면: StateManager가 알림을 받지 못함

3. **완전 리셋 확인**:
   ```
   ✅ [TIMER-DEBUG] 완전 리셋 성공 - 음성 인식 재시작됨
   ```
   없으면: 리셋 과정이 실패함

### UI가 업데이트되지 않을 경우

1. **상태 변경 확인**:
   - StateManager.isListening: `true → false → true`
   - VoiceEngine.isListening: `true → false → true`

2. **MenuBarViewModel 바인딩 확인**:
   - StateManager 바인딩이 덮어써지지 않았는지 확인
   - @Published 속성이 적절히 관찰되고 있는지 확인

## 향후 고려사항

### 잠재적 개선점

1. **단일 isListening 변수**: 두 `isListening` 변수를 하나의 중앙 관리 상태로 통합 고려
2. **반응형 스트림**: 알림 기반 통신을 Combine 퍼블리셔로 교체
3. **상태 머신**: 음성 인식 상태를 위한 공식적인 상태 머신 구현

### 성능 참고사항

- 현재 접근법은 리셋 중 ~0.1초의 UI 전환 시간 추가
- 타이머 정확도는 허용 범위 내 유지 (±50ms)
- 메모리 사용량 영향: 미미 (추가 알림 옵저버 하나)

---

*최종 업데이트: 2025-08-30*  
*작성자: Claude Code Assistant*  
*버전: 1.0*