# AI Voice Control

음성 명령으로 AI 데스크톱 앱과 터미널 도구를 제어하는 macOS 네이티브 애플리케이션

## 주요 기능

- 🎙️ **음성 인식**: 한국어/영어 실시간 음성 인식
- 🚀 **앱 제어**: Claude Desktop, ChatGPT, Perplexity 등 AI 앱 통합 제어
- 💻 **터미널 지원**: iTerm2와 Terminal.app에서 CLI 도구 제어
- 🔇 **노이즈 제거**: macOS Voice Isolation API로 깨끗한 음성 인식
- 🗣️ **음성 출력**: AI 응답을 음성으로 읽어주는 TTS 기능

## 시스템 요구사항

- macOS 15.0 이상
- 마이크 접근 권한
- 접근성 권한
- 자동화 권한 (AppleScript)

## 설치 방법

1. 프로젝트를 클론합니다:
```bash
git clone https://github.com/yourusername/AIVoiceControl.git
cd AIVoiceControl
```

2. Xcode에서 프로젝트를 엽니다:
```bash
open AIVoiceControl.xcodeproj
```

3. 빌드 및 실행 (Cmd+R)

## 사용 방법

1. 앱 실행 후 메뉴바에서 아이콘을 찾습니다
2. 설정에서 AI 앱을 등록하고 웨이크 워드를 설정합니다
3. 웨이크 워드를 말하여 앱을 활성화합니다
4. 음성으로 명령을 입력하고 End 워드로 전송합니다

### 예시
- "클로드" (웨이크 워드)
- "파이썬으로 퀵소트 구현해줘. 오버." (명령 + End 워드)

## 개발 상태

현재 단계별 구현 중입니다. 진행 상황은 `Docs/step-list.json`에서 확인할 수 있습니다.

## 라이선스

MIT License - [LICENSE](LICENSE) 파일 참조

## 기여하기

이슈와 풀 리퀘스트를 환영합니다. 기여하기 전에 `Docs/implementation-guide.md`를 참고해주세요.