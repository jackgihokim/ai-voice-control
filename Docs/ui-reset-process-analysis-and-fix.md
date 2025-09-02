# UI 리셋 프로세스 분석 및 수정 계획
> 59초 타이머와 Enter 키의 UI 업데이트 메커니즘 상세 분석

## 1. 현재 59초 타이머 UI 리셋 프로세스 (정상 작동)

### 1.1 이벤트 발생 순서

```
1. VoiceRecognitionEngine.performScheduledRestart()
   ↓
2. NotificationCenter.post(.timerExpiredReset)
   ↓
3. VoiceControlStateManager.handleTimerExpiredReset()
   ↓
4. Task { await completeReset(clearTextField: true) }
   ↓
5. completeReset() 실행
```

### 1.2 completeReset 내부 UI 업데이트 프로세스

#### Step 1: stopListening() 호출
```swift
// VoiceControlStateManager.stopListening() - line 103-145
1. guard isListening && !isTransitioning 체크
2. isTransitioning = true 설정
3. isListening = false 설정 ← 🔴 UI 업데이트 트리거
4. voiceEngine?.stopListening() 호출
5. stopCountdownTimer() 호출
6. NotificationCenter.post(.voiceRecognitionReset)
7. NotificationCenter.post(.voiceControlStateChanged, ["isListening": false])
8. defer { isTransitioning = false } 실행
```

**UI 변화 과정:**
- `isListening = false` → MenuBarViewModel이 관찰 → 버튼 텍스트 "Stop Listening" → "Start Listening"

#### Step 2: 텍스트 버퍼 클리어 (UI와 무관)
```swift
await clearAllTextBuffers()
```

#### Step 3: 텍스트 필드 클리어 (UI와 무관)
```swift
if clearTextField {
    await clearActiveAppTextField()
}
```

#### Step 4: 대기
```swift
await Task.sleep(nanoseconds: 500_000_000) // 0.5초
```

#### Step 5: startListening() 호출
```swift
// VoiceControlStateManager.startListening() - line 59-100
1. guard !isListening && !isTransitioning 체크
2. isTransitioning = true 설정
3. isListening = true 설정 ← 🔴 UI 업데이트 트리거
4. voiceEngine.startListening() 호출
5. startCountdownTimer() 호출
6. NotificationCenter.post(.voiceControlStateChanged, ["isListening": true])
7. defer { isTransitioning = false } 실행
```

**UI 변화 과정:**
- `isListening = true` → MenuBarViewModel이 관찰 → 버튼 텍스트 "Start Listening" → "Stop Listening"

### 1.3 UI 업데이트 메커니즘

```swift
// MenuBarViewModel.swift - line 176-183
private func setupStateManagerBindings() {
    stateManager.$isListening
        .assign(to: &$isListening)  // StateManager의 isListening 변경을 자동으로 관찰
    
    stateManager.$remainingTime
        .assign(to: &$remainingTime)
}
```

**핵심: @Published var isListening의 변경이 즉시 UI에 반영됨**

## 2. 현재 Enter 키 UI 리셋 프로세스 (문제 발생)

### 2.1 이벤트 발생 순서

```
1. KeyboardEventMonitor.handleKeyEvent()
   ↓
2. NotificationCenter.post(.enterKeyPressed)
   ↓
3. VoiceControlStateManager.handleEnterKeyPressed()
   ↓
4. Task { await completeReset(clearTextField: false) }
   ↓
5. completeReset() 실행
```

### 2.2 문제 분석

Enter 키와 59초 타이머 모두 동일한 `completeReset()` 함수를 호출하지만, UI가 업데이트되지 않는 이유:

#### 가능한 원인 1: isTransitioning 플래그 충돌
```swift
// completeReset() 내부에서
stopListening() {
    guard isListening && !isTransitioning else { return }  // ← 여기서 조기 반환?
    // ...
}
```

만약 Enter 키 이벤트가 빠르게 연속으로 발생하거나, 다른 작업 중이라면 `isTransitioning`이 true일 수 있음.

#### 가능한 원인 2: Task 실행 컨텍스트 문제
Enter 키 핸들러가 Task 내에서 실행되지만, @MainActor가 제대로 작동하지 않을 가능성.

#### 가능한 원인 3: 동기화 문제
`defer { isTransitioning = false }`가 비동기 작업과 충돌할 가능성.

## 3. 수정 계획

### 3.1 completeReset 함수 개선

```swift
func completeReset(clearTextField: Bool = true) async {
    let activeApp = NSWorkspace.shared.frontmostApplication
    #if DEBUG
    print("🔄 [RESET-DEBUG] Starting complete reset (clearTextField: \(clearTextField))")
    print("    App: \(activeApp?.localizedName ?? "Unknown")")
    print("    Current state: isListening=\(isListening), isTransitioning=\(isTransitioning)")
    #endif
    
    // isTransitioning 플래그를 completeReset 레벨에서 관리
    guard !isTransitioning else {
        #if DEBUG
        print("⚠️ [RESET-DEBUG] Already transitioning, skipping reset")
        #endif
        return
    }
    
    isTransitioning = true
    defer { isTransitioning = false }
    
    // 1. 명시적으로 isListening을 false로 설정 (stopListening 우회)
    if isListening {
        isListening = false  // UI 업데이트 트리거
        
        // Voice engine 중지
        voiceEngine?.stopListening()
        
        // Timer 중지
        stopCountdownTimer()
        
        // Notifications
        NotificationCenter.default.post(
            name: .voiceRecognitionReset,
            object: nil,
            userInfo: ["reason": "completeReset"]
        )
        
        NotificationCenter.default.post(
            name: .voiceControlStateChanged,
            object: nil,
            userInfo: ["isListening": false]
        )
        
        #if DEBUG
        print("🛑 [RESET-DEBUG] Voice recognition stopped")
        #endif
    }
    
    // 2. Clear text buffers
    await clearAllTextBuffers()
    
    // 3. Clear text field if needed
    if clearTextField {
        await clearActiveAppTextField()
    }
    
    // 4. Wait
    try? await Task.sleep(nanoseconds: 500_000_000)
    
    // 5. 명시적으로 isListening을 true로 설정 (startListening 우회)
    if !isListening {
        isListening = true  // UI 업데이트 트리거
        
        // Voice engine 시작
        do {
            if let engine = voiceEngine {
                try await engine.startListening()
            }
        } catch {
            #if DEBUG
            print("❌ [RESET-DEBUG] Failed to start voice engine: \(error)")
            #endif
            isListening = false
            return
        }
        
        // Timer 시작
        startCountdownTimer()
        
        // Notification
        NotificationCenter.default.post(
            name: .voiceControlStateChanged,
            object: nil,
            userInfo: ["isListening": true]
        )
        
        #if DEBUG
        print("🎙️ [RESET-DEBUG] Voice recognition restarted")
        #endif
    }
    
    #if DEBUG
    print("✅ [RESET-DEBUG] Complete reset finished")
    print("    Final state: isListening=\(isListening), isTransitioning=\(isTransitioning)")
    #endif
}
```

### 3.2 Enter 키 핸들러 개선

```swift
@objc private func handleEnterKeyPressed(_ notification: Notification) {
    let activeApp = NSWorkspace.shared.frontmostApplication
    let reason = notification.userInfo?["reason"] as? String ?? "unknown"
    let clearTextField = notification.userInfo?["clearTextField"] as? Bool ?? false
    let sourceComponent = notification.userInfo?["sourceComponent"] as? String ?? "unknown"
    let timestamp = notification.userInfo?["timestamp"] as? Date ?? Date()
    
    #if DEBUG
    print("⏎ [ENTER-KEY-DEBUG] \(sourceComponent)에서 Enter 키 리셋 요청")
    print("    활성 앱: \(activeApp?.localizedName ?? "Unknown")")
    print("    이유: \(reason), clearTextField: \(clearTextField)")
    print("    현재 상태: isListening=\(isListening), isTransitioning=\(isTransitioning)")
    #endif
    
    // MainActor에서 실행 보장
    Task { @MainActor in
        // UI 업데이트를 명시적으로 트리거
        await completeReset(clearTextField: clearTextField)
        
        #if DEBUG
        print("✅ [ENTER-KEY-DEBUG] Enter 키 리셋 완료")
        print("    최종 상태: isListening=\(isListening)")
        print("    Voice engine 상태: \(voiceEngine?.isListening ?? false)")
        #endif
    }
}
```

### 3.3 대안: 간단한 수정

현재 코드를 최소한으로 수정하려면:

```swift
func completeReset(clearTextField: Bool = true) async {
    // ... 기존 코드 ...
    
    // stopListening() 대신 직접 처리
    if isListening {
        isListening = false  // 즉시 UI 업데이트
        voiceEngine?.stopListening()
        stopCountdownTimer()
        // ... notifications ...
    }
    
    // ... 중간 처리 ...
    
    // startListening() 대신 직접 처리
    isListening = true  // 즉시 UI 업데이트
    try? await voiceEngine?.startListening()
    startCountdownTimer()
    // ... notifications ...
}
```

## 4. 테스트 계획

### 4.1 테스트 시나리오

1. **Enter 키 단일 입력**
   - Enter 키 입력 시 메뉴바 버튼이 변경되는지 확인
   - 콘솔 로그로 상태 변경 추적

2. **Enter 키 연속 입력**
   - 빠르게 Enter 키를 여러 번 입력
   - isTransitioning 플래그가 중복 실행을 막는지 확인

3. **59초 타이머와 Enter 키 혼용**
   - 59초 타이머 리셋 직후 Enter 키 입력
   - 두 리셋이 충돌하지 않는지 확인

### 4.2 예상 로그 출력

```
⏎ [ENTER-KEY-DEBUG] KeyboardEventMonitor에서 Enter 키 리셋 요청
🔄 [RESET-DEBUG] Starting complete reset (clearTextField: false)
🛑 [RESET-DEBUG] Voice recognition stopped
🎙️ [RESET-DEBUG] Voice recognition restarted
✅ [RESET-DEBUG] Complete reset finished
✅ [ENTER-KEY-DEBUG] Enter 키 리셋 완료
```

### 4.3 UI 변경 확인

메뉴바 버튼 텍스트:
1. 초기: "Stop Listening"
2. stopListening 후: "Start Listening" (잠시 표시)
3. startListening 후: "Stop Listening"

## 5. 구현 우선순위

1. **우선순위 1**: completeReset에서 stopListening/startListening 대신 직접 isListening 설정
2. **우선순위 2**: isTransitioning 플래그를 completeReset 레벨에서 관리
3. **우선순위 3**: Enter 키 핸들러에서 Task { @MainActor in ... } 명시

## 6. 결론

Enter 키 리셋 시 UI가 업데이트되지 않는 문제는 `isTransitioning` 플래그와 `stopListening()`/`startListening()` 함수의 guard 문에서 발생할 가능성이 높습니다. 

해결 방법:
1. `completeReset()` 함수에서 직접 `isListening` 상태를 변경
2. `isTransitioning` 플래그를 `completeReset()` 레벨에서 관리
3. UI 업데이트가 확실하게 일어나도록 명시적인 상태 변경

이렇게 수정하면 Enter 키와 59초 타이머 모두 동일한 UI 업데이트 동작을 보이게 됩니다.

---

*문서 작성일: 2025-08-31*  
*작성자: Claude Code Assistant*  
*버전: 1.0*