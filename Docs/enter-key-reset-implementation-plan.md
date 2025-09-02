# Enter 키 리셋 구현 계획
> 59초 타이머 리셋 메커니즘과 동일한 방식으로 Enter 키 리셋 구현

## 개요

현재 Enter 키 입력 시 `completeReset(clearTextField: false)`를 직접 호출하는 방식을 59초 타이머와 동일한 StateManager 위임 패턴으로 변경합니다. 단, Enter 키의 경우 텍스트 필드를 지우지 않는다는 차이점만 유지합니다.

## 현재 구조 분석

### 59초 타이머 리셋 플로우
```
1. VoiceEngine 타이머 만료
   ↓
2. performScheduledRestart() 
   ↓
3. NotificationCenter.post(.timerExpiredReset)
   ↓
4. StateManager.handleTimerExpiredReset()
   ↓
5. completeReset(clearTextField: true)
```

### 현재 Enter 키 리셋 플로우
```
1. KeyboardEventMonitor Enter 키 감지
   ↓
2. NotificationCenter.post(.enterKeyPressed)
   ↓
3. StateManager.handleEnterKeyPressed()
   ↓
4. 직접 completeReset(clearTextField: false) 호출
```

## 변경 계획

### 목표
Enter 키 리셋도 59초 타이머와 동일한 위임 패턴을 사용하도록 변경하여:
- 일관된 리셋 메커니즘
- 동일한 로깅 및 디버깅 패턴
- 통일된 상태 관리

### 핵심 원칙
1. **StateManager 중심 관리**: 모든 리셋이 StateManager를 통해 흐름
2. **위임 패턴 사용**: 직접 호출 대신 NotificationCenter를 통한 위임
3. **clearTextField 차이 유지**: Enter 키는 텍스트 필드를 지우지 않음

## 상세 구현 계획

### 1. KeyboardEventMonitor 수정

**파일**: `AIVoiceControl/Core/Utilities/KeyboardEventMonitor.swift`

#### 현재 코드 (line 93-102)
```swift
#if DEBUG
print("⏎ Enter key detected in target app - posting timer reset notification")
#endif

// Post notification to reset timer
NotificationCenter.default.post(
    name: .enterKeyPressed,
    object: nil,
    userInfo: ["timestamp": Date()]
)
```

#### 변경 후 코드
```swift
#if DEBUG
let activeApp = NSWorkspace.shared.frontmostApplication
print("⏎ [KEYBOARD-MONITOR] Enter key detected in target app - delegating to StateManager")
print("    App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
#endif

// StateManager에게 완전한 리셋 과정 위임
// clearTextField는 false로 설정 (Enter 키 입력 시 텍스트 필드는 자체적으로 처리됨)
NotificationCenter.default.post(
    name: .enterKeyPressed,
    object: nil,
    userInfo: [
        "reason": "enterKeyPressed",
        "clearTextField": false,  // Enter 키의 핵심 차이점
        "sourceComponent": "KeyboardEventMonitor",
        "timestamp": Date()
    ]
)
```

### 2. VoiceControlStateManager 수정

**파일**: `AIVoiceControl/Core/Managers/VoiceControlStateManager.swift`

#### 현재 handleEnterKeyPressed 메서드 (line 374-384)
```swift
@objc private func handleEnterKeyPressed(_ notification: Notification) {
    let activeApp = NSWorkspace.shared.frontmostApplication
    #if DEBUG
    print("⏎ [TIMER-DEBUG] Enter key pressed - performing complete reset - Active App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
    print("   Timestamp: \(notification.userInfo?["timestamp"] as? Date ?? Date())")
    #endif
    
    Task {
        // Enter 키의 경우 텍스트 필드는 지우지 않음 (사용자가 입력을 완료했을 가능성)
        await completeReset(clearTextField: false)
    }
}
```

#### 변경 후 handleEnterKeyPressed 메서드
```swift
@objc private func handleEnterKeyPressed(_ notification: Notification) {
    let activeApp = NSWorkspace.shared.frontmostApplication
    let reason = notification.userInfo?["reason"] as? String ?? "unknown"
    let clearTextField = notification.userInfo?["clearTextField"] as? Bool ?? false
    let sourceComponent = notification.userInfo?["sourceComponent"] as? String ?? "unknown"
    let timestamp = notification.userInfo?["timestamp"] as? Date ?? Date()
    
    #if DEBUG
    print("⏎ [ENTER-KEY-DEBUG] \(sourceComponent)에서 Enter 키 리셋 요청 - 완전 리셋 수행")
    print("    활성 앱: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
    print("    이유: \(reason), clearTextField: \(clearTextField)")
    print("    타임스탬프: \(timestamp)")
    print("    현재 상태: isListening=\(isListening), isTransitioning=\(isTransitioning)")
    #endif
    
    Task {
        // UI 업데이트 보장을 위해 StateManager를 통한 완전 리셋 수행
        // Enter 키의 경우 clearTextField는 false (NotificationCenter를 통해 전달받음)
        await completeReset(clearTextField: clearTextField)
        
        #if DEBUG
        print("✅ [ENTER-KEY-DEBUG] Enter 키 리셋 완료")
        print("    최종 상태: isListening=\(isListening), isTransitioning=\(isTransitioning)")
        print("    Voice engine 상태: \(voiceEngine?.isListening ?? false)")
        #endif
    }
}
```

### 3. 로깅 태그 통일

#### 변경 전 로그 태그
- 59초 타이머: `[TIMER-DEBUG]`, `[VOICE-ENGINE]`
- Enter 키: `[TIMER-DEBUG]`, `[KEYBOARD-MONITOR]`

#### 변경 후 로그 태그 체계
- 59초 타이머: `[TIMER-EXPIRED-DEBUG]`, `[VOICE-ENGINE]`
- Enter 키: `[ENTER-KEY-DEBUG]`, `[KEYBOARD-MONITOR]`
- 공통 리셋: `[RESET-DEBUG]`

### 4. completeReset 메서드 로깅 개선

**현재 completeReset 로깅**
```swift
#if DEBUG
print("🔄 [TIMER-DEBUG] Starting complete reset (clearTextField: \(clearTextField)) - App: \(activeApp?.localizedName ?? "Unknown")")
```

**변경 후 completeReset 로깅**
```swift
#if DEBUG
let resetSource = Thread.current.threadDictionary["resetSource"] as? String ?? "unknown"
print("🔄 [RESET-DEBUG] Starting complete reset from \(resetSource) (clearTextField: \(clearTextField))")
print("    App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
```

## 동기화 흐름 비교

### 59초 타이머 리셋 흐름
```
1. VoiceEngine 타이머 만료 (59초)
   │
   ▼
2. VoiceEngine.performScheduledRestart()
   │ 📡 [VOICE-ENGINE] StateManager에게 59초 타이머 만료 위임
   │
   ▼
3. NotificationCenter.post(.timerExpiredReset)
   │ userInfo: ["reason": "timerExpired", "clearTextField": true]
   │
   ▼
4. StateManager.handleTimerExpiredReset()
   │ ⏰ [TIMER-EXPIRED-DEBUG] 타이머 만료 리셋 수행
   │
   ▼
5. StateManager.completeReset(clearTextField: true)
```

### Enter 키 리셋 흐름 (변경 후)
```
1. KeyboardEventMonitor Enter 키 감지
   │
   ▼
2. KeyboardEventMonitor.handleKeyEvent()
   │ ⏎ [KEYBOARD-MONITOR] StateManager에게 Enter 키 리셋 위임
   │
   ▼
3. NotificationCenter.post(.enterKeyPressed)
   │ userInfo: ["reason": "enterKeyPressed", "clearTextField": false]
   │
   ▼
4. StateManager.handleEnterKeyPressed()
   │ ⏎ [ENTER-KEY-DEBUG] Enter 키 리셋 수행
   │
   ▼
5. StateManager.completeReset(clearTextField: false)
```

## 테스트 시나리오

### 1. Enter 키 리셋 동작 확인
- Enter 키 입력 시 음성 인식이 중지되고 재시작되는지 확인
- 메뉴바 버튼이 "Stop Listening" → "Start Listening" → "Stop Listening"으로 변경되는지 확인
- 텍스트 필드가 지워지지 않는지 확인 (핵심 차이점)

### 2. 로그 출력 확인
```bash
# Expected log sequence for Enter key
⏎ [KEYBOARD-MONITOR] Enter key detected in target app - delegating to StateManager
⏎ [ENTER-KEY-DEBUG] KeyboardEventMonitor에서 Enter 키 리셋 요청 - 완전 리셋 수행
🔄 [RESET-DEBUG] Starting complete reset from enterKey (clearTextField: false)
🛑 [RESET-DEBUG] 음성 인식 중지
🎙️ [RESET-DEBUG] 음성 인식 시작
✅ [ENTER-KEY-DEBUG] Enter 키 리셋 완료
```

### 3. 동작 일관성 확인
- 59초 타이머와 Enter 키 리셋이 동일한 패턴으로 작동
- 유일한 차이점은 clearTextField 값 (타이머: true, Enter: false)

## 예상 효과

### 장점
1. **일관된 리셋 메커니즘**: 모든 리셋이 동일한 패턴 사용
2. **명확한 로깅**: 리셋 소스를 쉽게 구분 가능
3. **유지보수 용이**: 한 곳에서 리셋 로직 관리
4. **디버깅 개선**: 통일된 로그 태그와 상세한 상태 정보

### 주의사항
1. **clearTextField 차이 유지**: Enter 키는 항상 false
2. **기존 동작 보존**: 사용자 경험 변화 없음
3. **로그 레벨**: DEBUG 빌드에서만 상세 로그 출력

## 구현 순서

1. **KeyboardEventMonitor 수정**
   - NotificationCenter userInfo 확장
   - 로그 메시지 개선

2. **VoiceControlStateManager 수정**
   - handleEnterKeyPressed 메서드 개선
   - 로그 태그 통일

3. **테스트 및 검증**
   - Enter 키 리셋 동작 확인
   - 로그 출력 검증
   - 59초 타이머와 동작 비교

## 결론

이 계획을 통해 Enter 키 리셋과 59초 타이머 리셋이 동일한 StateManager 위임 패턴을 사용하게 됩니다. 유일한 차이점은 텍스트 필드 처리 여부이며, 이는 userInfo를 통해 명확하게 전달됩니다. 결과적으로 더 일관되고 유지보수가 쉬운 코드가 됩니다.

---

*문서 작성일: 2025-08-31*  
*작성자: Claude Code Assistant*  
*버전: 1.0*