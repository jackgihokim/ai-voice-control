import Foundation
import ApplicationServices
import AppKit

/// Accessibility API를 사용한 텍스트 입력 자동화 클래스
@MainActor
class TextInputAutomator {
    
    // MARK: - Singleton
    static let shared = TextInputAutomator()
    private init() {}
    
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
        print("⌨️ Using keyboard simulation for text replacement")
        #endif
        
        // 전체 선택 (Command+A)
        try KeyboardSimulator.shared.selectAll()
        usleep(50_000) // 0.05초 대기
        
        // 새 텍스트 입력
        try KeyboardSimulator.shared.typeText(text)
        
        #if DEBUG
        print("✅ Keyboard text replacement completed")
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
        print("⌨️ Using keyboard simulation for text input")
        #endif
        
        // CGEvent를 사용한 키보드 시뮬레이션
        for character in text {
            try simulateKeyPress(for: character)
        }
        
        #if DEBUG
        print("✅ Keyboard simulation completed")
        #endif
    }
    
    /// 개별 문자에 대한 키 입력 시뮬레이션
    private func simulateKeyPress(for character: Character) throws {
        let characterString = String(character)
        
        // 특수 문자 처리
        if let keyCode = getKeyCode(for: character) {
            simulateKeyCode(keyCode)
        } else {
            // Unicode 문자 처리
            simulateUnicodeCharacter(characterString)
        }
        
        // 키 간격 조정 (너무 빠르면 일부 앱에서 인식하지 못함)
        usleep(10_000) // 0.01초
    }
    
    /// 문자에 대응하는 키 코드 반환
    private func getKeyCode(for character: Character) -> CGKeyCode? {
        let keyMap: [Character: CGKeyCode] = [
            " ": 49,  // Space
            "\n": 36, // Return
            "\t": 48, // Tab
            "\r": 36, // Return (alternative)
            
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14,
            "f": 3, "g": 5, "h": 4, "i": 34, "j": 38,
            "k": 40, "l": 37, "m": 46, "n": 45, "o": 31,
            "p": 35, "q": 12, "r": 15, "s": 1, "t": 17,
            "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
            "5": 23, "6": 22, "7": 26, "8": 28, "9": 25
        ]
        
        return keyMap[Character(character.lowercased())]
    }
    
    /// 키 코드로 키 입력 시뮬레이션
    private func simulateKeyCode(_ keyCode: CGKeyCode) {
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        
        keyDownEvent?.post(tap: .cghidEventTap)
        usleep(5_000) // 0.005초
        keyUpEvent?.post(tap: .cghidEventTap)
    }
    
    /// Unicode 문자 입력 시뮬레이션
    private func simulateUnicodeCharacter(_ character: String) {
        for unicodeScalar in character.unicodeScalars {
            let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
            let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            
            // UInt32를 UniChar(UInt16)로 변환
            let unicharValue = UInt16(unicodeScalar.value & 0xFFFF)
            keyDownEvent?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [unicharValue])
            keyUpEvent?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [unicharValue])
            
            keyDownEvent?.post(tap: .cghidEventTap)
            usleep(5_000)
            keyUpEvent?.post(tap: .cghidEventTap)
        }
    }
}

// MARK: - Async Extensions

extension TextInputAutomator {
    
    /// 비동기 텍스트 입력 (앱 활성화 대기 포함)
    func inputTextToAppAsync(_ text: String, app: AppConfiguration) async throws {
        try await inputTextToApp(text, app: app)
    }
}