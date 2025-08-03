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
    var defaultExecutionWords: [String] = ["Execute", "Run", "Go"]
    
    // MARK: - Advanced Settings
    var logLevel: LogLevel = .info
    var enableDebugMode: Bool = false
    var maxRecordingDuration: TimeInterval = 30.0
    var processingTimeout: TimeInterval = 10.0
    
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