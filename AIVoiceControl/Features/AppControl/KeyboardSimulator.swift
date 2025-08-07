import Foundation
import ApplicationServices

/// 키보드 입력 시뮬레이션을 위한 유틸리티 클래스
@MainActor
class KeyboardSimulator {
    
    // MARK: - Singleton
    static let shared = KeyboardSimulator()
    private init() {}
    
    // MARK: - Types
    
    enum KeyboardError: LocalizedError {
        case accessibilityNotAuthorized
        case keySimulationFailed
        
        var errorDescription: String? {
            switch self {
            case .accessibilityNotAuthorized:
                return "Accessibility permission is required for keyboard simulation"
            case .keySimulationFailed:
                return "Failed to simulate keyboard input"
            }
        }
    }
    
    // MARK: - Key Codes
    
    /// 자주 사용되는 키들의 키 코드 매핑
    static let keyCodeMap: [String: CGKeyCode] = [
        // Special keys
        "return": 36,
        "enter": 36,
        "tab": 48,
        "space": 49,
        "delete": 51,
        "escape": 53,
        "command": 55,
        "shift": 56,
        "capslock": 57,
        "option": 58,
        "control": 59,
        "fn": 63,
        
        // Arrow keys
        "left": 123,
        "right": 124,
        "down": 125,
        "up": 126,
        
        // Function keys
        "f1": 122, "f2": 120, "f3": 99, "f4": 118,
        "f5": 96, "f6": 97, "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        
        // Numbers
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
        "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
        
        // Letters
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14,
        "f": 3, "g": 5, "h": 4, "i": 34, "j": 38,
        "k": 40, "l": 37, "m": 46, "n": 45, "o": 31,
        "p": 35, "q": 12, "r": 15, "s": 1, "t": 17,
        "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6
    ]
    
    // MARK: - Public Methods
    
    /// 키 조합을 시뮬레이션합니다 (예: Command+V)
    /// - Parameters:
    ///   - keys: 누를 키들의 배열 (첫 번째부터 순서대로 누름)
    ///   - delay: 키 사이의 지연 시간 (마이크로초)
    /// - Throws: KeyboardError
    func simulateKeyCombo(_ keys: [String], delay: UInt32 = 10_000) throws {
        guard isAccessibilityEnabled() else {
            throw KeyboardError.accessibilityNotAuthorized
        }
        
        #if DEBUG
        print("⌨️ Simulating key combo: \(keys.joined(separator: "+"))")
        #endif
        
        var keyCodes: [CGKeyCode] = []
        
        // 키 코드 변환
        for key in keys {
            guard let keyCode = Self.keyCodeMap[key.lowercased()] else {
                #if DEBUG
                print("⚠️ Unknown key: \(key)")
                #endif
                continue
            }
            keyCodes.append(keyCode)
        }
        
        guard !keyCodes.isEmpty else {
            throw KeyboardError.keySimulationFailed
        }
        
        // 모든 키를 누른 상태로 만들기
        for keyCode in keyCodes {
            let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
            keyDownEvent?.post(tap: .cghidEventTap)
            usleep(delay)
        }
        
        // 모든 키를 역순으로 놓기
        for keyCode in keyCodes.reversed() {
            let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
            keyUpEvent?.post(tap: .cghidEventTap)
            usleep(delay)
        }
        
        #if DEBUG
        print("✅ Key combo simulation completed")
        #endif
    }
    
    /// 단일 키를 시뮬레이션합니다
    /// - Parameters:
    ///   - key: 누를 키 이름
    ///   - delay: 키 누름과 놓음 사이의 지연 시간 (마이크로초)
    /// - Throws: KeyboardError
    func simulateKey(_ key: String, delay: UInt32 = 5_000) throws {
        guard isAccessibilityEnabled() else {
            throw KeyboardError.accessibilityNotAuthorized
        }
        
        guard let keyCode = Self.keyCodeMap[key.lowercased()] else {
            throw KeyboardError.keySimulationFailed
        }
        
        #if DEBUG
        print("⌨️ Simulating key: \(key)")
        #endif
        
        let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        
        keyDownEvent?.post(tap: .cghidEventTap)
        usleep(delay)
        keyUpEvent?.post(tap: .cghidEventTap)
        
        #if DEBUG
        print("✅ Key simulation completed")
        #endif
    }
    
    /// 텍스트를 타이핑 시뮬레이션합니다
    /// - Parameters:
    ///   - text: 입력할 텍스트
    ///   - charDelay: 문자 사이의 지연 시간 (마이크로초)
    /// - Throws: KeyboardError
    func typeText(_ text: String, charDelay: UInt32 = 10_000) throws {
        guard isAccessibilityEnabled() else {
            throw KeyboardError.accessibilityNotAuthorized
        }
        
        #if DEBUG
        print("⌨️ Typing text: '\(text)'")
        #endif
        
        for character in text {
            try typeCharacter(character)
            usleep(charDelay)
        }
        
        #if DEBUG
        print("✅ Text typing completed")
        #endif
    }
    
    /// Enter 키를 시뮬레이션합니다
    /// - Throws: KeyboardError
    func sendEnter() throws {
        try simulateKey("return")
    }
    
    /// 텍스트를 입력하고 Enter를 누릅니다
    /// - Parameter text: 입력할 텍스트
    /// - Throws: KeyboardError
    func typeTextAndSubmit(_ text: String) throws {
        try typeText(text)
        usleep(100_000) // 0.1초 대기
        try sendEnter()
    }
    
    // MARK: - Private Methods
    
    /// 개별 문자를 타이핑합니다
    private func typeCharacter(_ character: Character) throws {
        let characterString = String(character)
        
        // 키 매핑에서 찾기
        if let keyCode = Self.keyCodeMap[characterString.lowercased()] {
            let needsShift = character.isUppercase || "!@#$%^&*()_+{}|:\"<>?".contains(character)
            
            if needsShift {
                // Shift + 키 조합
                let shiftDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 56, keyDown: true)
                let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
                let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
                let shiftUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 56, keyDown: false)
                
                shiftDownEvent?.post(tap: .cghidEventTap)
                usleep(5_000)
                keyDownEvent?.post(tap: .cghidEventTap)
                usleep(5_000)
                keyUpEvent?.post(tap: .cghidEventTap)
                usleep(5_000)
                shiftUpEvent?.post(tap: .cghidEventTap)
            } else {
                // 일반 키 입력
                let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
                let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
                
                keyDownEvent?.post(tap: .cghidEventTap)
                usleep(5_000)
                keyUpEvent?.post(tap: .cghidEventTap)
            }
        } else {
            // Unicode 문자 처리
            try typeUnicodeCharacter(characterString)
        }
    }
    
    /// Unicode 문자를 입력합니다
    private func typeUnicodeCharacter(_ character: String) throws {
        for unicodeScalar in character.unicodeScalars {
            let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
            let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            
            let unicharValue = UInt16(unicodeScalar.value & 0xFFFF)
            keyDownEvent?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [unicharValue])
            keyUpEvent?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [unicharValue])
            
            keyDownEvent?.post(tap: .cghidEventTap)
            usleep(5_000)
            keyUpEvent?.post(tap: .cghidEventTap)
        }
    }
    
    /// Accessibility 권한이 활성화되어 있는지 확인
    private func isAccessibilityEnabled() -> Bool {
        let checkOptionKey = kAXTrustedCheckOptionPrompt.takeRetainedValue()
        let options = [checkOptionKey: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

// MARK: - Convenience Extensions

extension KeyboardSimulator {
    
    /// 복사 (Command+C)
    func copy() throws {
        try simulateKeyCombo(["command", "c"])
    }
    
    /// 붙여넣기 (Command+V)
    func paste() throws {
        try simulateKeyCombo(["command", "v"])
    }
    
    /// 잘라내기 (Command+X)
    func cut() throws {
        try simulateKeyCombo(["command", "x"])
    }
    
    /// 전체 선택 (Command+A)
    func selectAll() throws {
        try simulateKeyCombo(["command", "a"])
    }
    
    /// 실행 취소 (Command+Z)
    func undo() throws {
        try simulateKeyCombo(["command", "z"])
    }
    
    /// 다시 실행 (Command+Shift+Z)
    func redo() throws {
        try simulateKeyCombo(["command", "shift", "z"])
    }
}