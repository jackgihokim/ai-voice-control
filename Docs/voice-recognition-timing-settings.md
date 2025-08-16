# 음성인식 타임아웃 및 딜레이 설정 가이드

## 개요
AI Voice Control 앱의 음성인식 시스템에는 다양한 타임아웃과 딜레이 설정이 있습니다. 이 문서는 각 설정의 목적, 현재 값, 작동 방식을 상세히 설명합니다.

## 1. 사용자 설정 가능한 타임아웃/딜레이

### 1.1 Recognition Restart Delay (음성인식 재시작 지연)
- **위치**: Settings → Voice → Voice Recognition Timing
- **파일**: `UserSettings.swift:35`, `VoiceRecognitionEngine.swift:380`
- **기본값**: 1.0초
- **범위**: 0.5초 ~ 5.0초 (0.5초 단위)
- **용도**: 음성이 끝났다고 판단된 후(`isFinal = true`) 새로운 음성인식을 시작하기까지 대기 시간
- **작동 방식**:
  ```swift
  // VoiceRecognitionEngine.swift:394
  DispatchQueue.main.asyncAfter(deadline: .now() + restartDelay) {
      // 음성인식 재시작
  }
  ```
- **권장 설정**:
  - 빠른 대화: 0.5초
  - 일반 대화: 1.0초 (기본값)
  - 천천히 말하는 경우: 2.0~3.0초

### 1.2 Silence Tolerance (침묵 허용 시간)
- **위치**: Settings → Voice → Voice Recognition Timing
- **파일**: `UserSettings.swift:36`
- **기본값**: 2.0초
- **범위**: 1.0초 ~ 10.0초 (0.5초 단위)
- **용도**: Apple Speech Framework가 침묵을 감지하여 음성이 끝났다고 판단하는 임계값
- **참고**: 현재 UI에만 표시되고 실제 Speech Framework에는 적용되지 않음 (향후 구현 예정)

### 1.3 Max Recording Duration (최대 녹음 시간)
- **위치**: Settings → General → Advanced
- **파일**: `UserSettings.swift:31`
- **기본값**: 30.0초
- **범위**: 5초 ~ 60초 (5초 단위)
- **용도**: 단일 음성인식 세션의 최대 길이 제한
- **참고**: 현재 UI에만 표시되고 실제로는 사용되지 않음

### 1.4 Processing Timeout (처리 타임아웃)
- **위치**: Settings → General → Advanced
- **파일**: `UserSettings.swift:32`
- **기본값**: 10.0초
- **범위**: 5초 ~ 30초 (1초 단위)
- **용도**: 음성인식 처리 최대 대기 시간
- **참고**: 현재 UI에만 표시되고 실제로는 사용되지 않음

### 1.5 Continuous Input Mode (연속 입력 모드)
- **위치**: Settings → Voice → Voice Recognition Timing
- **파일**: `UserSettings.swift:37`
- **기본값**: true
- **용도**: 여러 음성 세션의 텍스트를 누적할지 여부
- **작동 방식**: 활성화 시 이전 세션의 텍스트가 유지되며 새 텍스트가 추가됨

## 2. 고정 시스템 타임아웃

### 2.1 Max Continuous Time (최대 연속 시간)
- **파일**: `VoiceRecognitionEngine.swift:34`
- **값**: 58.0초 (고정)
- **용도**: Apple의 60초 제한을 피하기 위한 자동 재시작 타이머
- **작동 방식**:
  ```swift
  // 58초마다 자동으로 음성인식을 재시작
  Timer.scheduledTimer(withTimeInterval: maxContinuousTime, repeats: false)
  ```
- **이유**: Apple Speech Framework는 60초 이상 연속 음성인식을 허용하지 않음

### 2.2 Command Timeout (명령 타임아웃)
- **파일**: `WakeWordDetector.swift:10`
- **값**: 5.0초 (고정)
- **용도**: 웨이크 워드 감지 후 명령 입력 대기 시간
- **작동 방식**:
  ```swift
  // 웨이크 워드 감지 후 5초 내에 명령이 없으면 리셋
  Timer.scheduledTimer(withTimeInterval: commandTimeout, repeats: false)
  ```
- **시나리오**: "Claude" (웨이크 워드) → 5초 대기 → 타임아웃 → 상태 리셋

### 2.3 Session Timeout (세션 타임아웃)
- **파일**: `TextInputAutomator.swift:23`
- **값**: 10.0초 (고정)
- **용도**: 텍스트 입력 세션 간 구분
- **작동 방식**: 10초 이상 입력이 없으면 새로운 세션으로 간주하고 이전 텍스트 추적 리셋

### 2.4 Session Timeout Threshold (세션 임계값)
- **파일**: `WakeWordDetector.swift:17`
- **값**: 2.0초 (고정)
- **용도**: 연속 입력 모드에서 새 세션 감지
- **작동 방식**: 2초 이상 간격이 있으면 새로운 음성 세션으로 판단

## 3. 하드코딩된 딜레이

### 3.1 음성인식 재시작 딜레이
```swift
// VoiceRecognitionEngine.swift:401
Task.sleep(nanoseconds: 100_000_000) // 0.1초
```
- **용도**: 음성인식 정지 후 재시작 전 짧은 대기
- **이유**: 시스템 리소스 정리를 위한 버퍼 시간

### 3.2 서버 에러 재시도 딜레이
```swift
// VoiceRecognitionEngine.swift:347
Task.sleep(nanoseconds: 1_000_000_000) // 1초
```
- **용도**: 음성인식 서버 에러(코드 203) 발생 시 재시도 대기
- **이유**: 서버 부하 방지 및 복구 시간 제공

### 3.3 스케줄된 재시작 딜레이
```swift
// VoiceRecognitionEngine.swift:448
Task.sleep(nanoseconds: 500_000_000) // 0.5초
```
- **용도**: 58초 자동 재시작 시 대기 시간
- **이유**: 부드러운 전환을 위한 버퍼

### 3.4 키보드 입력 딜레이

#### 백스페이스 딜레이
```swift
// TextInputAutomator.swift:169
Thread.sleep(forTimeInterval: 0.05) // 0.05초
```
- **용도**: 한글 입력 시 백스페이스 간 대기
- **이유**: 한글 조합 문자 처리를 위한 충분한 시간 확보

#### 클립보드 작업 딜레이
```swift
// TextInputAutomator.swift:322, 502
usleep(50_000) // 0.05초 (50ms)
```
- **용도**: 클립보드 복사/붙여넣기 작업 간 대기
- **이유**: 시스템 클립보드 동기화 시간 확보

#### 텍스트 입력 후 딜레이
```swift
// TextInputAutomator.swift:247
Task.sleep(nanoseconds: 100_000_000) // 0.1초
```
- **용도**: 텍스트 입력 후 Enter 키 전송 전 대기
- **이유**: 텍스트 입력 완료 보장

### 3.5 앱 활성화 딜레이
```swift
// TextInputAutomator.swift:103
Task.sleep(nanoseconds: 200_000_000) // 0.2초
```
- **용도**: 앱 활성화 후 텍스트 입력 전 대기
- **이유**: 앱이 완전히 포커스를 받을 때까지 대기

## 4. 타이밍 설정 간 상호작용

### 4.1 음성 세션 플로우
```
사용자 발화 시작
    ↓
[음성인식 진행]
    ↓
침묵 감지 (Apple 내부 ~1-2초)
    ↓
isFinal = true
    ↓
[Recognition Restart Delay 대기] ← 사용자 설정 가능 (0.5~5초)
    ↓
새 음성인식 시작
```

### 4.2 연속 입력 모드 플로우
```
첫 번째 발화
    ↓
[Session Timeout Threshold 확인] (2초)
    ↓
새 세션 감지 시 → 텍스트 누적
    ↓
두 번째 발화
    ↓
누적된 텍스트 + 현재 텍스트 결합
```

### 4.3 웨이크 워드 타임아웃 플로우
```
웨이크 워드 감지
    ↓
[Command Timeout 시작] (5초)
    ↓
명령 입력 대기
    ↓
타임아웃 시 → 상태 리셋
```

## 5. 권장 설정 조합

### 빠른 응답이 필요한 경우
- Recognition Restart Delay: 0.5초
- Continuous Input Mode: 비활성화
- 용도: 짧은 명령어 위주의 사용

### 긴 문장 입력이 필요한 경우
- Recognition Restart Delay: 2.0~3.0초
- Continuous Input Mode: 활성화
- 용도: 문서 작성, 긴 메시지 입력

### 표준 대화형 사용
- Recognition Restart Delay: 1.0초 (기본값)
- Continuous Input Mode: 활성화
- 용도: 일반적인 AI 앱과의 대화

## 6. 주의사항

1. **Apple 60초 제한**: 음성인식은 60초를 초과할 수 없으므로 58초에 자동 재시작됨
2. **한글 입력 딜레이**: 한글 조합 문자 특성상 영문보다 긴 딜레이 필요
3. **서버 부하**: 너무 짧은 재시작 딜레이는 서버 부하를 증가시킬 수 있음
4. **시스템 리소스**: 짧은 딜레이는 CPU 사용량을 증가시킬 수 있음

## 7. 향후 개선 계획

1. **Silence Tolerance 실제 적용**: Apple Speech Framework의 세그먼트 타임아웃 설정 구현
2. **Max Recording Duration 활용**: 실제 녹음 시간 제한 구현
3. **Processing Timeout 활용**: 음성 처리 타임아웃 로직 구현
4. **동적 딜레이 조정**: 시스템 부하에 따른 자동 딜레이 조정

## 8. 디버깅 팁

### 타이밍 문제 디버깅
1. Xcode 콘솔에서 다음 로그 확인:
   - `"🔄 Will restart recognition in X seconds"`
   - `"📚 Session text accumulated"`
   - `"⏱️ Command timeout"`

2. 설정 조정 후 앱 재시작 권장

3. 문제 발생 시 확인 사항:
   - Recognition Restart Delay 설정값
   - Continuous Input Mode 상태
   - 콘솔의 타이밍 관련 로그

---

*마지막 업데이트: 2025-08-16*
*작성자: Claude Code*