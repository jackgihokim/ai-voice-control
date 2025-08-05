# 마이크 권한 다이얼로그 문제 해결 방법

## 문제 개요

AIVoiceControl 앱에서 마이크 권한 요청 시 다이얼로그가 나타나지 않고 자동으로 거부(`denied`)되는 문제가 발생했습니다.

### 증상
- Settings > Permissions > Microphone에서 "Request Permission" 클릭
- 권한 다이얼로그 없이 즉시 `denied` 상태로 변경
- System Settings > Privacy & Security > Microphone에 앱이 목록에 나타나지 않음
- 이전에는 정상 작동했지만 `tccutil reset` 후 문제 발생

## 근본 원인 분석

### 1차 원인: LSUIElement 설정 의심
처음에는 `LSUIElement = true` 설정(메뉴바 앱)이 권한 다이얼로그를 차단한다고 추정했습니다.

**검증 결과:** LSUIElement를 비활성화(`false`)해도 문제 지속

### 2차 원인: Gatekeeper 차단 (실제 원인)
최종적으로 **macOS Gatekeeper가 앱을 신뢰할 수 없는 앱으로 분류**하여 권한 다이얼로그를 차단하고 있었습니다.

#### 진단 과정
```bash
# Gatekeeper 상태 확인
spctl -a -v /path/to/AIVoiceControl.app
# 결과: rejected

# 디버그 출력 분석
🎤 Current microphone permission status: 0 (notDetermined)
🎤 LSUIElement: false
🎤 Bundle ID: com.jack-kim-dev.AIVoiceControl
🎤 AVCaptureDevice.requestAccess result: false
🎤 New permission status: 2 (denied)
```

**핵심 발견:** 앱 설정은 모두 올바르지만 macOS 시스템 레벨에서 앱을 차단

## 해결 방법

### 1단계: LSUIElement 비활성화 (개발 중)
권한 요청 시에는 메뉴바 앱 모드를 비활성화합니다.

**Info.plist 수정:**
```xml
<!-- 권한 요청을 위해 임시로 비활성화 -->
<!-- 
<key>LSUIElement</key>
<true/>
-->
```

**자동화 스크립트 (`switch-to-regular.sh`):**
```bash
#!/bin/bash
echo "🔄 앱을 일반 모드로 전환합니다..."

# Info.plist에서 LSUIElement 비활성화 (중복 주석 방지)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_PATH="$SCRIPT_DIR/AIVoiceControl/Info.plist"

sed -i '' 's/<!-- <key>LSUIElement<\/key>/<key>LSUIElement<\/key>/' "$PLIST_PATH"
sed -i '' 's/<true\/> -->/<true\/>/' "$PLIST_PATH"
sed -i '' 's/<key>LSUIElement<\/key>/<!-- <key>LSUIElement<\/key>/' "$PLIST_PATH"
sed -i '' 's/<true\/>/<true\/> -->/' "$PLIST_PATH"

echo "✅ 일반 모드로 전환 완료"
```

### 2단계: Gatekeeper 문제 해결 (핵심)

#### 방법 1: Ad-hoc 코드 서명
```bash
# 앱에 ad-hoc 서명 적용
codesign --force --deep --sign - /path/to/AIVoiceControl.app
```

#### 방법 2: Extended Attributes 제거
```bash
# Quarantine 속성 제거
xattr -cr /path/to/AIVoiceControl.app
```

#### 방법 3: 시스템 설정에서 수동 허용
1. **시스템 설정 → 개인정보 보호 및 보안**
2. **보안** 섹션에서 차단된 앱 메시지 확인
3. **"확인 후 열기"** 또는 **"열기"** 클릭

### 3단계: 권한 상태 리셋
```bash
# 앱의 모든 권한 리셋
tccutil reset All com.jack-kim-dev.AIVoiceControl
```

## 코드 수정 사항

### 1. PermissionManager.swift 디버깅 강화

**추가된 디버깅 정보:**
```swift
func requestMicrophonePermission() async -> PermissionStatus {
    return await withCheckedContinuation { continuation in
        #if os(macOS)
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        #if DEBUG
        print("🎤 === MICROPHONE PERMISSION REQUEST DEBUG ===")
        print("🎤 Current microphone permission status: \(currentStatus) (raw: \(currentStatus.rawValue))")
        print("🔍 Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("🔍 Bundle path: \(Bundle.main.bundlePath)")
        print("🔍 Executable path: \(Bundle.main.executablePath ?? "Unknown")")
        let isMenuBarOnly = Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool ?? false
        print("🔍 App is menu bar only: \(isMenuBarOnly)")
        print("🔍 Process name: \(ProcessInfo.processInfo.processName)")
        print("🔍 Process ID: \(ProcessInfo.processInfo.processIdentifier)")
        print("🎤 ==========================================")
        #endif
```

**권한 요청 콜백 디버깅:**
```swift
AVCaptureDevice.requestAccess(for: .audio) { granted in
    #if DEBUG
    print("🎤 === PERMISSION REQUEST CALLBACK ===")
    print("🎤 AVCaptureDevice.requestAccess result: \(granted)")
    print("🎤 New permission status: \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue)")
    if !granted {
        print("⚠️ Permission request failed - likely due to LSUIElement configuration or system policy")
        print("💡 Solution: Remove LSUIElement temporarily during first launch")
    } else {
        print("✅ Permission granted successfully!")
    }
    print("🎤 ================================")
    #endif
```

### 2. 프로젝트 설정 수정

**AIVoiceControl.xcodeproj/project.pbxproj:**
```
GENERATE_INFOPLIST_FILE = NO;
INFOPLIST_FILE = AIVoiceControl/Info.plist;
```

이 설정으로 Xcode가 소스 Info.plist 파일을 사용하도록 보장합니다.

## 권한 상태 코드 참조

```
0 = notDetermined  (권한 미결정 - 다이얼로그 표시 가능)
1 = restricted     (시스템 정책으로 제한)
2 = denied         (사용자가 거부하거나 시스템이 차단)
3 = authorized     (권한 승인됨)
```

## 문제 해결 체크리스트

### 개발 단계
- [ ] `LSUIElement` 비활성화 (`switch-to-regular.sh` 실행)
- [ ] 앱 빌드 및 배포
- [ ] Gatekeeper 상태 확인 (`spctl -a -v app.app`)
- [ ] 필요시 ad-hoc 서명 (`codesign --force --deep --sign -`)
- [ ] 시스템 설정에서 앱 허용
- [ ] TCC 권한 리셋 (`tccutil reset All bundle.id`)
- [ ] 권한 요청 테스트

### 배포 단계
- [ ] 개발자 계정으로 정식 코드 서명
- [ ] 공증(Notarization) 완료
- [ ] `LSUIElement` 재활성화 (`switch-to-menubar.sh` 실행)

## 예방 방법

### 1. 개발 환경 설정
```bash
# 개발자 모드 활성화 (관리자 권한 필요)
sudo spctl --master-disable
```

### 2. 코드 서명 자동화
```bash
# Xcode Build Phase에 추가
if [ "$CONFIGURATION" = "Debug" ]; then
    codesign --force --deep --sign - "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
fi
```

### 3. 두 단계 배포 전략
1. **첫 실행**: 일반 앱 모드로 권한 요청
2. **후속 실행**: 메뉴바 앱 모드로 전환

## 기술적 배경

### macOS 보안 정책
- **Gatekeeper**: 신뢰할 수 없는 앱의 실행을 차단
- **TCC (Transparency, Consent, and Control)**: 권한 관리 시스템
- **LSUIElement**: 메뉴바 전용 앱은 일부 시스템 기능에 제한

### 권한 다이얼로그 표시 조건
1. 앱이 Gatekeeper 검증을 통과해야 함
2. 앱이 올바른 서명과 entitlements를 가져야 함
3. 앱이 quarantine 상태가 아니어야 함
4. 사용자가 이전에 거부하지 않았어야 함

## 결론

**마이크 권한 다이얼로그가 나타나지 않는 주된 원인은 macOS Gatekeeper의 앱 차단**이었습니다. LSUIElement 설정이나 코드 문제가 아니라, 개발 중인 앱에 대한 시스템 레벨의 보안 정책이 권한 다이얼로그를 차단했습니다.

**해결 과정:**
1. LSUIElement 비활성화 (권한 요청 시)
2. Gatekeeper 우회 (ad-hoc 서명 또는 시스템 설정 허용)
3. TCC 권한 상태 리셋
4. 권한 요청 재시도

이 문제는 **개발 단계에서만 발생**하며, 정식으로 서명되고 공증된 앱에서는 발생하지 않습니다.