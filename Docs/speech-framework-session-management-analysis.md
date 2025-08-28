# Speech Framework 세션 관리 및 result.isFinal 메커니즘 분석

## 목차
1. [개요](#개요)
2. [result.isFinal 판단 메커니즘](#resultisFinal-판단-메커니즘)
3. [세션 종료 확인/확정 코드](#세션-종료-확인확정-코드)
4. [세션 생명주기](#세션-생명주기)
5. [실제 시나리오 예시](#실제-시나리오-예시)

## 개요

AI Voice Control 앱에서 음성인식 세션의 시작과 종료는 Apple Speech Framework와 앱 자체 로직의 조합으로 관리됩니다. 특히 `result.isFinal` 플래그는 Speech Framework가 자체적으로 판단하는 핵심 메커니즘입니다.

## result.isFinal 판단 메커니즘

### 누가 판단하는가?
**Apple Speech Framework가 100% 자체적으로 판단합니다.**

### Speech Framework의 isFinal 판단 기준

1. **침묵 감지**
   - 약 1-2초 동안 침묵이 지속되면 문장이 끝났다고 판단
   - 자연스러운 말하기 패턴에서 문장 간 휴지(pause) 감지

2. **문장 구조 분석**
   - 완성된 문장 구조 감지 (주어+동사+목적어 등)
   - 문법적으로 완전한 단위 인식

3. **음성 패턴 분석**
   - 억양 변화 (문장 끝의 하강 억양)
   - 톤과 피치 변화 패턴
   - 말하기 속도 변화

4. **최대 길이 제한**
   - 너무 긴 연속 입력은 강제로 구분
   - 메모리 및 처리 효율성을 위한 제한

## 세션 종료 확인/확정 코드

### 1. isFinal 처리 로직
**위치**: `VoiceRecognitionEngine.swift:375-404`

```swift
if result.isFinal {
    // Speech Framework가 "이 문장은 끝났다"고 판단
    recognizedText = transcription
    
    // 설정에서 재시작 지연 시간 가져오기 (현재 기본값: 0.5초)
    let userSettings = UserSettings.load()
    let restartDelay = userSettings.recognitionRestartDelay
    
    #if DEBUG
    print("📝 Final: \(transcription)")
    print("🔄 Will restart recognition in \(restartDelay) seconds...")
    #endif
    
    // 현재 transcription 초기화
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.currentTranscription = ""
    }
    
    // 음성인식 재시작 (연속 듣기를 위해)
    if isListening {
        DispatchQueue.main.asyncAfter(deadline: .now() + restartDelay) {
            if self.isListening {
                Task {
                    self.stopListening()      // 현재 세션 종료
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
                    try? await self.startListening()  // 새 세션 시작
                }
            }
        }
    }
}
```

### 2. 세션 종료 메서드
**위치**: `VoiceRecognitionEngine.swift:195-223`

```swift
func stopListening() {
    guard recognitionState == .listening else { return }
    
    recognitionState = .stopping
    
    // 재시작 타이머 취소
    restartTimer?.invalidate()
    restartTimer = nil
    
    // 음성인식 리소스 정리
    cleanupRecognitionTask()
    
    // 오디오 레벨 모니터링 중지
    stopAudioLevelMonitoring()
    
    // Voice Isolation 정리
    if isVoiceIsolationEnabled {
        Task {
            try? await voiceIsolationManager.cleanupAudioSession()
        }
    }
    
    // 상태 초기화
    isListening = false
    recognitionState = .idle
    audioLevel = 0.0
    isRestarting = false
}
```

### 3. 음성인식 작업 정리
**위치**: `VoiceRecognitionEngine.swift:472-494`

```swift
private func cleanupRecognitionTask() {
    #if DEBUG
    print("🧹 Cleaning up recognition task")
    #endif
    
    // 1. 기존 작업 취소
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

## 세션 생명주기

### 전체 흐름도

```
[세션 시작]
startListening()
    ↓
audioEngine.prepare()
audioEngine.start()
    ↓
recognitionTask 생성
    ↓
[음성 인식 진행 중]
handleRecognitionResult() 반복 호출
- partial results (isFinal = false)
- 실시간 텍스트 업데이트
    ↓
[Speech Framework 판단]
result.isFinal = true
    ↓
recognitionRestartDelay 대기 (0.5초)
    ↓
stopListening()
- recognitionTask.cancel()
- recognitionRequest.endAudio()
- audioEngine.stop()
    ↓
[세션 종료]
    ↓
100ms 대기
    ↓
startListening()
    ↓
[새 세션 시작]
```

### 세션 종료 트리거

#### 1. 자동 종료 트리거

**isFinal 감지** (정상 종료)
- Speech Framework의 자체 판단
- 문장 완료 시 자동 발생
- 0.5초 후 자동 재시작

**59초 타이머** (강제 재시작)
- Apple의 1분 제한 회피
- `maxContinuousTime: TimeInterval = 59.0`
- 59초마다 자동으로 세션 재시작

**에러 발생**
- 서버 에러 (코드 203)
- 음성인식 불가능
- 네트워크 문제

#### 2. 수동 종료 트리거

**사용자 액션**
- Toggle 버튼으로 stopListening() 호출
- 설정 변경 시
- 앱 종료 시

**시스템 이벤트**
- 마이크 권한 변경
- 다른 앱이 마이크 독점
- 시스템 리소스 부족

## 실제 시나리오 예시

### 시나리오 1: 정상적인 문장 입력

```
시간    | 이벤트                           | isFinal | 동작
--------|----------------------------------|---------|------------------
0.0초   | 사용자: "안녕하세요" 시작          | false   | 세션 시작
0.5초   | partial result: "안"             | false   | 텍스트 업데이트
1.0초   | partial result: "안녕"           | false   | 텍스트 업데이트
1.5초   | partial result: "안녕하세요"       | false   | 텍스트 업데이트
2.0초   | (침묵 감지)                      | -       | Framework 분석 중
2.5초   | final result: "안녕하세요"        | true    | 문장 완료 판단
3.0초   | stopListening() + startListening()| -       | 세션 재시작 (0.5초 대기)
3.1초   | 새 세션 대기 중                   | -       | 다음 음성 대기
```

### 시나리오 2: 긴 침묵 포함 입력

```
시간    | 이벤트                           | isFinal | 동작
--------|----------------------------------|---------|------------------
0초     | "오늘 날씨가" 말함                | false   | 부분 인식
1초     | partial: "오늘 날씨가"            | false   | 텍스트 업데이트
2초     | (3초 침묵 시작)                  | false   | 대기 중
3초     | (계속 침묵)                      | false   | Framework 분석
4초     | final: "오늘 날씨가"              | true    | 침묵으로 인한 종료
4.5초   | 세션 재시작                       | -       | 새 세션
5초     | "정말 좋네요" 말함                | false   | 새 문장 시작
6초     | partial: "정말"                  | false   | 텍스트 업데이트
7초     | partial: "정말 좋네요"            | false   | 텍스트 업데이트
8초     | final: "정말 좋네요"              | true    | 문장 완료
```

### 시나리오 3: 59초 자동 재시작

```
시간    | 이벤트                           | 동작
--------|----------------------------------|------------------
0초     | 세션 시작, 연속 대화 진행         | 정상 인식
30초    | 계속 대화 중                     | 정상 인식
58초    | 아직 대화 중                     | 정상 인식
59초    | maxContinuousTime 도달           | 자동 재시작 트리거
59.5초  | performScheduledRestart() 실행   | 세션 종료 후 재시작
60초    | 새 세션에서 계속 인식            | 정상 인식 재개
```

### 시나리오 4: 웨이크 워드 감지 후 처리

```
시간    | 이벤트                           | 동작
--------|----------------------------------|------------------
0초     | "Claude" (웨이크 워드)           | 웨이크 워드 감지
0.5초   | VoiceControlStateManager.completeReset() | 전체 시스템 리셋
1초     | 새 세션 시작                     | 명령 대기 상태
2초     | "오늘 일정 알려줘"                | 명령 인식
5초     | isFinal = true                  | 명령 완료
5.5초   | 세션 재시작                      | 다음 명령 대기
```

## 핵심 포인트 정리

1. **isFinal 판단 주체**
   - Apple Speech Framework가 100% 자체적으로 판단
   - 개발자가 직접 제어할 수 없음
   - 침묵, 문장 구조, 음성 패턴 등을 종합적으로 분석

2. **세션 관리**
   - 세션 시작: `startListening()` 호출
   - 세션 종료: `stopListening()` 호출
   - 세션 = 하나의 연속된 음성인식 작업 단위

3. **현재 설정값**
   - `recognitionRestartDelay`: 0.5초 (isFinal 후 재시작 대기)
   - `maxContinuousTime`: 59초 (Apple 제한 회피)
   - 침묵 감지: Speech Framework 자체 판단 (약 1-2초)

4. **자동 재시작 메커니즘**
   - isFinal 감지 시 0.5초 후 자동 재시작
   - 59초마다 강제 재시작
   - 에러 발생 시 자동 복구 시도

5. **세션 간 연속성**
   - 세션이 재시작되어도 WakeWordDetector 상태는 유지
   - 텍스트는 Speech Framework가 세션 내에서 자동 누적
   - 세션 간 텍스트 연결은 앱 로직으로 처리