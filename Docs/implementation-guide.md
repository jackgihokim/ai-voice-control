# Voice Control for AI Apps - 단계별 구현 가이드

## 개요
이 문서는 Voice Control for AI Apps를 단계별로 구현하기 위한 가이드입니다. 각 단계는 독립적으로 컴파일 및 실행 가능하며, 이전 단계의 기능이 정상 작동하는 것을 전제로 합니다.

## 프로젝트 구조
```
VoiceControlForAIApps/
├── VoiceControlForAIApps/
│   ├── App/
│   │   ├── VoiceControlApp.swift
│   │   └── Info.plist
│   ├── Core/
│   │   ├── Models/
│   │   ├── Managers/
│   │   └── Utilities/
│   ├── Features/
│   │   ├── MenuBar/
│   │   ├── VoiceRecognition/
│   │   ├── AppControl/
│   │   ├── TerminalControl/
│   │   ├── VoiceOutput/
│   │   └── WaveformUI/
│   └── Resources/
│       └── Assets.xcassets
└── VoiceControlForAIApps.xcodeproj
```

## 구현 단계

### Phase 1: 기본 인프라 구축 (1주)

#### Step 1: Menu Bar 앱 기본 구조 생성
**목표**: 메뉴바에서 실행되는 기본 앱 생성
- SwiftUI 기반 macOS 앱 프로젝트 생성
- Menu Bar 전용 앱으로 설정 (Dock 아이콘 숨김)
- 기본 메뉴 구조 구현 (About, Preferences, Quit)
- **테스트**: 앱이 메뉴바에만 표시되고 기본 메뉴가 작동하는지 확인

**파일 구조**:
```
App/
├── VoiceControlApp.swift
├── AppDelegate.swift
└── Info.plist
Features/MenuBar/
├── MenuBarView.swift
└── MenuBarViewModel.swift
```

#### Step 2: 설정 창 UI 구현 ✅
**목표**: 탭 기반 설정 창 구현
- SwiftUI로 설정 창 구현
- 탭 구조 생성 (앱 관리, 음성 설정, 일반 설정, 정보)
- 설정 데이터 모델 생성
- UserDefaults 연동
- **테스트**: 설정 창이 열리고 탭 전환이 작동하는지 확인

**구현된 추가 기능**:
- UltraSimpleTextField를 사용한 ViewBridge 에러 방지
- 앱별 커스텀 음성 설정 (selectedVoiceId, speechRate, voiceOutputVolume)
- Wake words와 Execution words 배열 지원
- Debug 모드에서 UserDefaults 리셋 기능
- 앱 등록 시 설치된 앱 자동 검색

**파일 구조**:
```
Features/Settings/
├── SettingsWindow.swift
├── SettingsViewModel.swift
├── SettingsWindowController.swift
├── Tabs/
│   ├── AppManagementTab.swift
│   ├── VoiceSettingsTab.swift
│   ├── GeneralSettingsTab.swift
│   └── AboutTab.swift
Core/Models/
├── AppConfiguration.swift
└── UserSettings.swift
Core/Utilities/
└── UltraSimpleTextField.swift  # ViewBridge 에러 방지 텍스트 필드
```

#### Step 3: 권한 요청 시스템 구현
**목표**: 필요한 시스템 권한 요청 및 관리
- 마이크 접근 권한 요청
- 접근성 권한 요청
- 자동화 권한 확인
- 권한 상태 모니터링
- **테스트**: 앱 실행 시 권한 요청이 나타나고 상태가 저장되는지 확인

**파일 구조**:
```
Core/Managers/
├── PermissionManager.swift
└── PermissionStatus.swift
Features/Permissions/
├── PermissionRequestView.swift
└── PermissionGuideView.swift
```

### Phase 2: 음성 인식 기반 구축 (1주)

#### Step 4: 기본 음성 인식 구현
**목표**: Speech Framework를 사용한 기본 음성 인식
- Speech Framework 설정
- 마이크 입력 스트림 구성
- 한국어/영어 음성 인식 구현
- 인식 결과 로깅
- **테스트**: 음성이 텍스트로 변환되어 콘솔에 출력되는지 확인

**파일 구조**:
```
Features/VoiceRecognition/
├── VoiceRecognitionManager.swift
├── SpeechRecognizerDelegate.swift
└── AudioEngine.swift
Core/Models/
└── RecognitionResult.swift
```

#### Step 5: Voice Isolation 통합
**목표**: macOS Voice Isolation API 적용
- Voice Isolation API 설정
- 노이즈 제거 토글 기능
- 오디오 품질 모니터링
- **테스트**: 시끄러운 환경에서 음성 인식 정확도가 향상되는지 확인

**파일 구조**:
```
Features/VoiceRecognition/
└── VoiceIsolationManager.swift
```

#### Step 6: 웨이크 워드 시스템 구현
**목표**: 항상 듣기 모드에서 웨이크 워드 감지
- 백그라운드 음성 감지 구현
- 웨이크 워드 매칭 알고리즘
- 다중 웨이크 워드 지원
- 웨이크 워드 감지 시 알림
- **테스트**: 웨이크 워드 말하면 감지되는지, 유사 단어는 무시하는지 확인

**파일 구조**:
```
Features/VoiceRecognition/
├── WakeWordDetector.swift
└── WakeWordMatcher.swift
Core/Models/
└── WakeWord.swift
```

### Phase 3: 앱 제어 시스템 구축 (1.5주)

#### Step 7: Accessibility API 기반 앱 제어
**목표**: 외부 앱 감지 및 기본 제어
- 실행 중인 앱 목록 가져오기
- 앱 활성화 (포커스 이동)
- 텍스트 입력 필드 감지
- **테스트**: Claude Desktop을 실행하고 포커스를 이동시킬 수 있는지 확인

**파일 구조**:
```
Features/AppControl/
├── AppControlManager.swift
├── AccessibilityHelper.swift
└── AppDetector.swift
Core/Models/
└── ControlledApp.swift
```

#### Step 8: 텍스트 입력 자동화
**목표**: 감지된 텍스트 필드에 자동 입력
- 텍스트 필드 접근성 요소 찾기
- 프롬프트 템플릿 삽입
- 음성 인식 텍스트 입력
- Enter 키 시뮬레이션
- **테스트**: Claude Desktop의 입력창에 텍스트가 자동으로 입력되는지 확인

**파일 구조**:
```
Features/AppControl/
├── TextInputAutomation.swift
└── KeyboardSimulator.swift
```

#### Step 9: Execution 워드 시스템 구현
**목표**: Execution 워드 감지 및 자동 전송
- Execution 워드 감지 로직
- 음성 입력 버퍼 관리
- Execution 워드 감지 시 Enter 키 전송
- **테스트**: Execution 워드를 말하면 입력이 전송되는지 확인

**파일 구조**:
```
Features/VoiceRecognition/
├── ExecutionWordDetector.swift
└── InputBuffer.swift
```

### Phase 4: 터미널 제어 구현 (1주)

#### Step 10: iTerm2 AppleScript 통합
**목표**: iTerm2 기본 제어 구현
- iTerm2 실행 상태 확인
- AppleScript를 통한 세션 제어
- 텍스트 전송 기능
- **테스트**: iTerm2에서 Claude Code를 실행하고 텍스트를 전송할 수 있는지 확인

**파일 구조**:
```
Features/TerminalControl/
├── ITermController.swift
├── AppleScriptRunner.swift
└── TerminalSession.swift
```

#### Step 11: 터미널 출력 캡처
**목표**: 터미널 응답 감지 및 처리
- iTerm2 출력 모니터링
- JSON 응답 파싱
- summary 필드 추출
- **테스트**: Claude Code의 응답에서 JSON을 정확히 추출하는지 확인

**파일 구조**:
```
Features/TerminalControl/
├── OutputCapture.swift
└── JSONResponseParser.swift
```

### Phase 5: 음성 출력 시스템 (1주)

#### Step 12: TTS 기본 구현
**목표**: AVSpeechSynthesizer를 사용한 음성 출력
- 시스템 음성 목록 로드
- 텍스트를 음성으로 변환
- 음성 속도/음량 조절
- **테스트**: 텍스트가 선택된 음성으로 출력되는지 확인

**파일 구조**:
```
Features/VoiceOutput/
├── TTSManager.swift
├── VoiceProfile.swift
└── SystemVoiceLoader.swift
```

#### Step 13: 음성 다운로드 안내
**목표**: 고품질 음성 다운로드 유도
- 설치된 음성 확인
- 미설치 음성 감지
- 시스템 설정 연결
- **테스트**: 고품질 음성이 없을 때 안내가 표시되는지 확인

**파일 구조**:
```
Features/VoiceOutput/
├── VoiceDownloadGuide.swift
└── SystemSettingsLauncher.swift
```

### Phase 6: UI 및 피드백 시스템 (1주)

#### Step 14: 파형 UI 구현
**목표**: 음성 레벨 시각화
- SwiftUI로 파형 애니메이션 구현
- 오디오 레벨 실시간 반영
- 앱별 색상 테마 적용
- 우측 상단 고정 위치
- **테스트**: 음성 입력/출력 시 파형이 움직이는지 확인

**파일 구조**:
```
Features/WaveformUI/
├── WaveformView.swift
├── WaveformViewModel.swift
├── AudioLevelMonitor.swift
└── FloatingWindow.swift
```

#### Step 15: 음성 및 시각적 피드백
**목표**: 웨이크 워드 인식 피드백
- 웨이크 워드 인식 시 음성 응답
- 파형 UI 색상 변경
- 앱 아이콘 표시
- 메뉴바 아이콘 애니메이션
- **테스트**: 웨이크 워드 인식 시 모든 피드백이 작동하는지 확인

**파일 구조**:
```
Features/Feedback/
├── FeedbackManager.swift
├── VoiceResponsePlayer.swift
└── VisualFeedbackAnimator.swift
```

### Phase 7: 통합 및 최적화 (1주)

#### Step 16: 앱 관리 기능 완성 ✅
**목표**: 앱 등록/삭제/설정 기능 구현
- 앱 검색 및 선택 UI
- 웨이크 워드/Execution 워드 설정
- 앱별 설정 저장
- **테스트**: 여러 앱을 등록하고 설정이 유지되는지 확인

**구현된 기능**:
- 설치된 앱 자동 검색 (Applications 폴더 스캔)
- Wake words 배열 지원 (다중 웨이크 워드)
- Execution words 배열 지원 (기본값: Execute, Run, Go)
- 앱별 커스텀 음성 설정 (편집 모드에서만 가능)
- 앱 활성화/비활성화 토글
- 앱 아이콘 자동 로드
- 에러 처리 및 로깅

**파일 구조**:
```
Features/Settings/Tabs/
└── AppManagementTab.swift  # 앱 관리 기능 통합 구현
    ├── AddAppSheet         # 새 앱 추가 UI
    ├── EditAppSheet        # 앱 설정 편집 UI
    └── AppRow             # 앱 목록 표시 컴포넌트
```

#### Step 17: 성능 최적화
**목표**: CPU/메모리 사용량 최적화
- 백그라운드 작업 최적화
- 메모리 누수 확인 및 수정
- 음성 인식 효율성 개선
- **테스트**: Activity Monitor에서 리소스 사용량 확인

#### Step 18: 에러 처리 및 안정성
**목표**: 예외 상황 처리
- 네트워크 오류 처리
- 권한 거부 시 대응
- 앱 응답 없음 처리
- 크래시 리포팅
- **테스트**: 다양한 예외 상황에서 앱이 안정적으로 작동하는지 확인

## 각 단계별 체크리스트

### 코드 작성 방식
- 코드 작성의 단계는 Step별로 진행하며 하나의 Step이 완료되면 멈추고 사용자가 다음 Step 작업 지시할 때 작업 시작 (step-list.json 참고)

### 코드 작성 전
- [ ] 이전 단계 기능이 정상 작동하는지 확인
- [ ] 필요한 의존성 확인
- [ ] 해당 기능의 Swift 6.1+ 최신 API 확인

### 코드 작성 후
- [ ] Xcode에서 컴파일 성공
- [ ] 런타임 에러 없음
- [ ] 기본 기능 테스트 통과
- [ ] 메모리 누수 없음
- [ ] Console 로그에 경고 없음

### 다음 단계 진행 전
- [ ] 현재 기능이 독립적으로 작동
- [ ] 코드 정리 및 주석 추가
- [ ] 간단한 사용 설명 작성

## 기술 스택 참고사항

### MCP 활용
- Context7 MCP 사용

### Swift 6.1+ 활용
- Structured Concurrency (async/await)
- Actor를 활용한 스레드 안전성
- Observation 프레임워크 활용

### macOS 15.0+ API
- 최신 SwiftUI 기능 활용
- Voice Isolation API
- 향상된 Accessibility API

### ViewBridge 에러 해결
- **모든 텍스트 입력에 UltraSimpleTextField 사용 필수**
- AppDelegate에서 SimpleViewBridgeKiller.activateNuclearOption() 호출
- 표준 SwiftUI TextField 사용 금지
- 상세 내용은 VIEWBRIDGE_NUCLEAR_SOLUTION.md 참조

### 디버깅 도구
- **UserDefaults 리셋**: 
  - 터미널: `./reset-app.sh`
  - Xcode: `-reset-defaults` 인자 추가
  - 디버그 메뉴: "Reset All Settings (Debug)"
- **에러 로깅**: 콘솔에서 앱 로딩 에러 확인

### 음성 설정 아키텍처
- **글로벌 설정**: 모든 앱의 기본값
- **앱별 설정**: nil일 때 글로벌 설정 사용
- **편집 흐름**: 앱 추가 → 편집 모드에서 음성 설정
- **AVSpeechSynthesizer**: @State로 유지하여 조기 해제 방지

### 써드파티 라이브러리
- 가능한 한 시스템 프레임워크만 사용
- 필요시 Swift Package Manager 활용