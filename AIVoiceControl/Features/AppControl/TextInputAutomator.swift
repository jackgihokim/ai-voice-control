import Foundation
import ApplicationServices
import AppKit
import Cocoa

/// Accessibility API를 사용한 텍스트 입력 자동화 클래스
@MainActor
class TextInputAutomator {
    
    // MARK: - Singleton
    static let shared = TextInputAutomator()
    private init() {
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceRecognitionReset(_:)),
            name: .voiceRecognitionReset,
            object: nil
        )
        
        #if DEBUG
        print("🔔 TextInputAutomator: Notification observers setup")
        #endif
    }
    
    @objc private func handleVoiceRecognitionReset(_ notification: Notification) {
        let reason = notification.userInfo?["reason"] as? String ?? "unknown"
        let clearTextField = notification.userInfo?["clearTextField"] as? Bool ?? false
        
        #if DEBUG
        print("🔄 TextInputAutomator: Received reset notification (reason: \(reason), clearTextField: \(clearTextField))")
        #endif
        
        resetIncrementalText()
        
        // 타이머 만료 시 텍스트 필드 클리어
        if clearTextField {
            Task {
                await clearActiveAppTextField()
            }
        }
    }
    
    /// 활성 앱의 텍스트 필드를 클리어
    private func clearActiveAppTextField() async {
        #if DEBUG
        print("🧹 Clearing active app's text field")
        #endif
        
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            #if DEBUG
            print("⚠️ No active app found")
            #endif
            return
        }
        
        // UI 업데이트 방지 플래그 설정
        VoiceControlStateManager.shared.isPerformingTextFieldOperation = true
        
        // 텍스트 필드 클리어 동안 카운트다운 타이머 일시 중지
        await VoiceControlStateManager.shared.stopCountdownTimer()
        
        // UI 업데이트가 완료되도록 잠시 대기
        #if DEBUG
        print("⏳ Waiting for UI updates to complete...")
        #endif
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
        
        do {
            // 포커스된 텍스트 필드를 찾아서 직접 빈 텍스트로 설정
            if let focusedElement = getFocusedTextElement() {
                #if DEBUG
                print("🔍 Found focused text element - attempting direct clear")
                #endif
                
                // 빈 텍스트로 직접 설정
                let clearResult = AXUIElementSetAttributeValue(
                    focusedElement,
                    kAXValueAttribute as CFString,
                    "" as CFTypeRef
                )
                
                if clearResult == .success {
                    #if DEBUG
                    print("✅ Text field cleared directly: \(activeApp.localizedName ?? "Unknown")")
                    #endif
                    return
                } else {
                    #if DEBUG
                    print("⚠️ Direct clear failed, trying keyboard method")
                    #endif
                }
            }
            
            // 직접 설정이 실패하면 키보드 방식으로 시도
            #if DEBUG
            print("⌨️ Trying keyboard method to clear text field")
            #endif
            
            // Select all text (Command+A)
            try KeyboardSimulator.shared.selectAll()
            
            #if DEBUG
            print("🔍 Text should be highlighted now - waiting 0.1 seconds...")
            #endif
            
            // 텍스트 선택 완료 대기
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
            
            #if DEBUG
            print("⌨️ Now attempting to delete selected text...")
            #endif
            
            // 백스페이스 한 번으로 선택된 텍스트 삭제
            try KeyboardSimulator.shared.sendBackspace()
            
            #if DEBUG
            print("✅ Text field cleared using space replacement: \(activeApp.localizedName ?? "Unknown")")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to clear text field: \(error)")
            #endif
        }
        
        // UI 업데이트 방지 플래그 해제
        VoiceControlStateManager.shared.isPerformingTextFieldOperation = false
        
        // remainingTime 업데이트
        VoiceControlStateManager.shared.remainingTime = VoiceControlStateManager.shared.maxTime
        
        // 텍스트 필드 클리어 완료 후 타이머 재시작
        await VoiceControlStateManager.shared.startCountdownTimer()
    }
    
    // MARK: - Properties
    
    /// 마지막으로 입력된 텍스트를 추적 (증분 업데이트용)
    private var lastInputText: String = ""
    /// 현재 활성화된 앱의 bundle ID
    private var currentAppBundleId: String?
    /// 마지막 입력 시간 (세션 연속성 감지용)
    private var lastInputTime: Date = Date()
    
    // MARK: - Types
    
    enum TextInputError: LocalizedError {
        case accessibilityNotAuthorized
        case noFocusedElement
        case textInputFailed
        case appNotFound
        case elementNotFound
        
        var errorDescription: String? {
            switch self {
            case .accessibilityNotAuthorized:
                return "Accessibility permission is required"
            case .noFocusedElement:
                return "No focused text element found"
            case .textInputFailed:
                return "Failed to input text"
            case .appNotFound:
                return "Target application not found"
            case .elementNotFound:
                return "Text input element not found"
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 현재 포커스된 앱에 텍스트를 입력합니다
    /// - Parameter text: 입력할 텍스트
    /// - Throws: TextInputError
    func inputTextToFocusedApp(_ text: String) throws {
        guard isAccessibilityEnabled() else {
            throw TextInputError.accessibilityNotAuthorized
        }
        
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            #if DEBUG
            print("⚠️ Empty text provided for input")
            #endif
            return
        }
        
        #if DEBUG
        print("🎯 Attempting to input text: '\(text)'")
        #endif
        
        // 방법 1: 포커스된 텍스트 필드에 직접 입력 시도
        if let focusedElement = getFocusedTextElement() {
            try inputTextDirectly(to: focusedElement, text: text)
            return
        }
        
        // 방법 2: 키보드 시뮬레이션으로 입력
        try inputTextViaKeyboard(text)
    }
    
    /// 특정 앱에 텍스트를 입력합니다
    /// - Parameters:
    ///   - text: 입력할 텍스트
    ///   - app: 대상 앱 설정
    /// - Throws: TextInputError
    func inputTextToApp(_ text: String, app: AppConfiguration) async throws {
        guard isAccessibilityEnabled() else {
            throw TextInputError.accessibilityNotAuthorized
        }
        
        // 앱이 활성화되어 있는지 확인
        guard let runningApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.bundleIdentifier == app.bundleIdentifier 
        }) else {
            throw TextInputError.appNotFound
        }
        
        // 앱을 포그라운드로 가져오기
        if !runningApp.isActive {
            _ = runningApp.activate(options: [.activateAllWindows])
            
            // 활성화 대기
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2초
        }
        
        #if DEBUG
        print("🎯 Inputting text to app: \(app.name)")
        print("   Bundle ID: \(app.bundleIdentifier)")
        print("   Text: '\(text)'")
        #endif
        
        try inputTextToFocusedApp(text)
    }
    
    /// 증분 방식으로 텍스트를 입력합니다 (이전 텍스트와의 차이점만 추가)
    /// - Parameter newText: 새로운 전체 텍스트
    /// - Throws: TextInputError
    func inputTextIncremental(_ newText: String) throws {
        guard isAccessibilityEnabled() else {
            throw TextInputError.accessibilityNotAuthorized
        }
        
        // 현재 활성 앱 확인
        let currentBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let currentTime = Date()
        
        // 앱이 변경되었으면 lastInputText 리셋
        let isNewSession = currentBundleId != currentAppBundleId
        
        if isNewSession {
            lastInputText = ""
            currentAppBundleId = currentBundleId
            
            #if DEBUG
            if currentBundleId != currentAppBundleId {
                print("🔄 New app detected - resetting text tracking")
            } else {
                print("⏰ Session timeout - resetting text tracking")
            }
            #endif
        }
        
        // 마지막 입력 시간 업데이트
        lastInputTime = currentTime
        
        #if DEBUG
        print("🔄 Incremental text input")
        print("   Previous: '\(lastInputText)'")
        print("   New: '\(newText)'")
        #endif
        
        // 텍스트 차이 계산
        let commonPrefixLength = findCommonPrefixLength(lastInputText, newText)
        let deleteCount = lastInputText.count - commonPrefixLength
        let addText = String(newText.dropFirst(commonPrefixLength))
        
        #if DEBUG
        print("   Common prefix length: \(commonPrefixLength)")
        print("   Delete count: \(deleteCount)")
        print("   Text to add: '\(addText)'")
        #endif
        
        // 삭제가 필요한 경우 백스페이스 전송
        if deleteCount > 0 {
            for _ in 0..<deleteCount {
                try KeyboardSimulator.shared.sendBackspace()
                // 한글 입력을 위한 긴 딜레이
                Thread.sleep(forTimeInterval: 0.05) // 0.05초로 증가
            }
        }
        
        // 새로운 텍스트 추가
        if !addText.isEmpty {
            try inputTextViaKeyboard(addText)
        }
        
        // 마지막 입력 텍스트 업데이트
        lastInputText = newText
        
        #if DEBUG
        print("✅ Incremental input completed")
        #endif
    }
    
    /// 두 문자열의 공통 접두사 길이를 찾습니다
    private func findCommonPrefixLength(_ str1: String, _ str2: String) -> Int {
        let minLength = min(str1.count, str2.count)
        var commonLength = 0
        
        let chars1 = Array(str1)
        let chars2 = Array(str2)
        
        for i in 0..<minLength {
            if chars1[i] == chars2[i] {
                commonLength += 1
            } else {
                break
            }
        }
        
        return commonLength
    }
    
    /// 추적 중인 텍스트를 리셋합니다
    func resetIncrementalText() {
        lastInputText = ""
        currentAppBundleId = nil
        lastInputTime = Date()
        
        #if DEBUG
        print("🔄 Incremental text tracking reset")
        #endif
    }
    
    /// Enter 키를 시뮬레이션합니다
    /// - Throws: TextInputError
    func sendEnterKey() throws {
        guard isAccessibilityEnabled() else {
            throw TextInputError.accessibilityNotAuthorized
        }
        
        #if DEBUG
        print("⏎ Sending Enter key")
        #endif
        
        try KeyboardSimulator.shared.sendEnter()
        
        #if DEBUG
        print("✅ Enter key sent")
        #endif
    }
    
    /// 텍스트를 입력하고 Enter 키를 전송합니다
    /// - Parameters:
    ///   - text: 입력할 텍스트
    ///   - app: 대상 앱 설정 (옵션)
    /// - Throws: TextInputError
    func inputTextAndSubmit(_ text: String, app: AppConfiguration? = nil) async throws {
        if let app = app {
            try await inputTextToApp(text, app: app)
        } else {
            try inputTextToFocusedApp(text)
        }
        
        // 텍스트 입력 후 잠깐 대기
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1초
        
        // Enter 키 전송
        try sendEnterKey()
    }
    
    /// 현재 텍스트를 지우고 새로운 텍스트로 교체합니다 (실시간 입력용)
    /// - Parameter text: 새로운 텍스트
    /// - Throws: TextInputError
    func replaceCurrentText(_ text: String) throws {
        #if DEBUG
        let isEnabled = isAccessibilityEnabled()
        print("🔍 TextInputAutomator - Accessibility check: \(isEnabled)")
        print("   AXIsProcessTrusted: \(AXIsProcessTrusted())")
        #endif
        
        guard isAccessibilityEnabled() else {
            #if DEBUG
            print("❌ Accessibility not authorized in TextInputAutomator")
            print("   Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
            print("   Process name: \(ProcessInfo.processInfo.processName)")
            #endif
            throw TextInputError.accessibilityNotAuthorized
        }
        
        #if DEBUG
        print("🔄 Replacing current text with: '\(text)'")
        #endif
        
        // 방법 1: 포커스된 텍스트 필드에 직접 교체
        if let focusedElement = getFocusedTextElement() {
            try replaceTextDirectly(to: focusedElement, text: text)
            return
        }
        
        // 방법 2: 키보드 시뮬레이션으로 전체 선택 후 교체
        try replaceTextViaKeyboard(text)
    }
    
    /// UI 요소에 직접 텍스트를 교체
    private func replaceTextDirectly(to element: AXUIElement, text: String) throws {
        #if DEBUG
        print("🔤 Attempting direct text replacement")
        #endif
        
        // 새 텍스트로 바로 설정 (기존 텍스트 덮어쓰기)
        let setValueResult = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )
        
        if setValueResult == .success {
            #if DEBUG
            print("✅ Direct text replacement successful")
            #endif
            return
        }
        
        #if DEBUG
        print("⚠️ Direct text replacement failed, using keyboard simulation")
        #endif
        
        // 직접 교체 실패시 키보드 시뮬레이션으로 대체
        try replaceTextViaKeyboard(text)
    }
    
    /// 키보드 시뮬레이션으로 텍스트를 교체
    private func replaceTextViaKeyboard(_ text: String) throws {
        #if DEBUG
        print("📋 Using clipboard replacement method to avoid IME conflicts: '\(text)'")
        #endif
        
        // 전체 선택 (Command+A)
        try KeyboardSimulator.shared.selectAll()
        usleep(50_000) // 0.05초 대기
        
        // 모든 텍스트를 클립보드 방식으로 입력하여 IME 충돌 방지
        try inputTextViaClipboard(text)
        
        #if DEBUG
        print("✅ Clipboard text replacement completed")
        #endif
    }
    
    // MARK: - Private Methods
    
    /// Accessibility 권한이 활성화되어 있는지 확인
    private func isAccessibilityEnabled() -> Bool {
        let checkOptionKey = kAXTrustedCheckOptionPrompt.takeRetainedValue()
        let options = [checkOptionKey: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    /// 현재 포커스된 텍스트 요소를 찾습니다
    private func getFocusedTextElement() -> AXUIElement? {
        // 시스템 전역 요소 가져오기
        let systemElement = AXUIElementCreateSystemWide()
        
        // 포커스된 앱 찾기
        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemElement, 
            kAXFocusedApplicationAttribute as CFString, 
            &focusedApp
        )
        
        guard appResult == .success, let focusedAppElement = focusedApp else {
            #if DEBUG
            print("⚠️ Could not get focused application")
            #endif
            return nil
        }
        
        // 포커스된 UI 요소 찾기
        var focusedElement: CFTypeRef?
        let elementResult = AXUIElementCopyAttributeValue(
            focusedAppElement as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard elementResult == .success, let element = focusedElement else {
            #if DEBUG
            print("⚠️ Could not get focused UI element")
            #endif
            return nil
        }
        
        let axElement = element as! AXUIElement
        
        // 텍스트 입력이 가능한 요소인지 확인
        if isTextInputElement(axElement) {
            #if DEBUG
            print("✅ Found focused text input element")
            #endif
            return axElement
        }
        
        #if DEBUG
        print("⚠️ Focused element is not a text input")
        #endif
        return nil
    }
    
    /// UI 요소가 텍스트 입력이 가능한지 확인
    private func isTextInputElement(_ element: AXUIElement) -> Bool {
        // Role 확인
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if roleResult == .success, let roleString = role as? String {
            let textInputRoles = [
                kAXTextFieldRole as String,
                kAXTextAreaRole as String,
                kAXComboBoxRole as String
            ]
            
            if textInputRoles.contains(roleString) {
                return true
            }
        }
        
        // Subrole 확인 (일부 텍스트 필드는 subrole로 구분됨)
        var subrole: CFTypeRef?
        let subroleResult = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole)
        
        if subroleResult == .success, let subroleString = subrole as? String {
            if subroleString.contains("TextField") || subroleString.contains("TextArea") {
                return true
            }
        }
        
        // Value 속성이 있는지 확인 (텍스트 입력 가능한 요소는 보통 value 속성을 가짐)
        var value: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        return valueResult == .success
    }
    
    /// UI 요소에 직접 텍스트를 입력
    private func inputTextDirectly(to element: AXUIElement, text: String) throws {
        #if DEBUG
        print("🔤 Attempting direct text input")
        #endif
        
        // 현재 텍스트 값 가져오기
        var currentValue: CFTypeRef?
        let getCurrentResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)
        
        let existingText = (currentValue as? String) ?? ""
        let newText = existingText + text
        
        #if DEBUG
        print("   Current text: '\(existingText)'")
        print("   New text will be: '\(newText)'")
        #endif
        
        // 새 텍스트 설정
        let setValueResult = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            newText as CFTypeRef
        )
        
        if setValueResult == .success {
            #if DEBUG
            print("✅ Direct text input successful")
            #endif
            return
        }
        
        #if DEBUG
        print("⚠️ Direct text input failed, error: \(setValueResult.rawValue)")
        #endif
        
        // 직접 입력 실패시 키보드 시뮬레이션으로 대체
        try inputTextViaKeyboard(text)
    }
    
    /// 키보드 시뮬레이션으로 텍스트 입력
    private func inputTextViaKeyboard(_ text: String) throws {
        #if DEBUG
        print("📋 Using clipboard method for all text to avoid IME conflicts: '\(text)'")
        #endif
        
        // 모든 텍스트를 클립보드 방식으로 입력하여 IME 충돌 방지
        try inputTextViaClipboard(text)
        
        #if DEBUG
        print("✅ Clipboard text input completed")
        #endif
    }
    
    
    /// 텍스트에 한글이 포함되어 있는지 확인
    private func containsKoreanText(_ text: String) -> Bool {
        return text.contains { isKoreanCharacter($0) }
    }
    
    /// 클립보드를 통한 텍스트 입력
    private func inputTextViaClipboard(_ text: String) throws {
        #if DEBUG
        print("📋 Using clipboard for text input: '\(text)'")
        #endif
        
        // 현재 클립보드 내용 백업
        let pasteboard = NSPasteboard.general
        let originalContent = pasteboard.string(forType: .string)
        
        // 새 텍스트를 클립보드에 복사
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 짧은 대기 후 붙여넣기
        usleep(50_000) // 0.05초
        
        try KeyboardSimulator.shared.paste()
        
        // 원래 클립보드 내용 복원 (선택적)
        if let original = originalContent {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                pasteboard.setString(original, forType: .string)
            }
        }
        
        #if DEBUG
        print("✅ Clipboard text input completed")
        #endif
    }
    
    
    /// 문자가 한글인지 확인
    private func isKoreanCharacter(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        let value = scalar.value
        // 한글 완성형 범위: AC00-D7AF
        // 한글 자모 범위: 1100-11FF, 3130-318F
        return (value >= 0xAC00 && value <= 0xD7AF) ||
               (value >= 0x1100 && value <= 0x11FF) ||
               (value >= 0x3130 && value <= 0x318F)
    }
    
}

// MARK: - Async Extensions

extension TextInputAutomator {
    
    /// 비동기 텍스트 입력 (앱 활성화 대기 포함)
    func inputTextToAppAsync(_ text: String, app: AppConfiguration) async throws {
        try await inputTextToApp(text, app: app)
    }
}