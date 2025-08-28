//
//  UserSettings.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import Foundation

struct UserSettings: Codable {
    // MARK: - General Settings
    var launchAtLogin: Bool = false
    var showMenuBarIcon: Bool = true
    var enableNotifications: Bool = true
    var autoStart: Bool = false
    
    // MARK: - Voice Settings
    var voiceLanguage: VoiceLanguage = .english
    var voiceInputSensitivity: Double = 0.5
    var voiceOutputVolume: Double = 0.8
    var enableVoiceIsolation: Bool = true
    var selectedVoiceId: String = ""
    var speechRate: Double = 0.5
    
    // MARK: - App Management
    var registeredApps: [AppConfiguration] = []
    
    // MARK: - Advanced Settings
    var logLevel: LogLevel = .info
    var enableDebugMode: Bool = false
    var maxRecordingDuration: TimeInterval = 30.0
    
    // MARK: - Voice Recognition Settings
    var recognitionRestartDelay: TimeInterval = 0.5    // 음성인식 재시작 지연 시간 (초) - deprecated
    var continuousInputMode: Bool = true               // 연속 입력 모드
    var autoAddPunctuation: Bool = false               // 자동 구두점 추가
    var punctuationStyle: PunctuationStyle = .conservative  // 구두점 추가 스타일
    
    // MARK: - Voice Control Automation
    var autoStartListening: Bool? = true               // 앱 시작 시 자동으로 음성인식 시작
    var showFloatingTimer: Bool? = true                // 플로팅 타이머 윈도우 표시
    var resetOnWakeWord: Bool? = true                  // 웨이크워드 감지 시 타이머 리셋
    var resetOnEnterKey: Bool? = true                  // Enter 키 입력 시 타이머 리셋
    var floatingTimerPosition: CGPoint? = CGPoint(x: 100, y: 100)  // 플로팅 타이머 위치
    var floatingTimerOpacity: Double? = 1.0            // 플로팅 타이머 투명도
    
    // MARK: - Static Methods
    
    static func load() -> UserSettings {
        guard let data = UserDefaults.standard.data(forKey: "UserSettings"),
              let settings = try? JSONDecoder().decode(UserSettings.self, from: data) else {
            return UserSettings() // Return default settings
        }
        return settings
    }
    
    func save() {
        guard let data = try? JSONEncoder().encode(self) else {
            print("Failed to encode UserSettings")
            return
        }
        UserDefaults.standard.set(data, forKey: "UserSettings")
    }
}

// MARK: - Supporting Enums

enum VoiceLanguage: String, CaseIterable, Codable {
    case english = "en-US"
    case korean = "ko-KR"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .korean: return "한국어"
        }
    }
}

enum LogLevel: String, CaseIterable, Codable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .debug: return "Debug"
        case .info: return "Info"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
}

enum PunctuationStyle: String, CaseIterable, Codable {
    case conservative = "conservative"
    case aggressive = "aggressive"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .conservative: return "확실한 경우만"
        case .aggressive: return "적극적으로"
        case .none: return "사용 안함"
        }
    }
    
    var description: String {
        switch self {
        case .conservative: return "명확한 종결어미만 인식"
        case .aggressive: return "모든 문장에 구두점 추가"
        case .none: return "구두점 추가하지 않음"
        }
    }
}