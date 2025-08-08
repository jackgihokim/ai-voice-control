//
//  AppConfiguration.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import Foundation
import AppKit

/// 텍스트 입력 모드
enum TextInputMode: String, Codable, CaseIterable {
    case incremental = "incremental"  // 차이점만 추가 (스트림 방식)
    case replace = "replace"          // 전체 교체 (기존 방식)
    
    var displayName: String {
        switch self {
        case .incremental:
            return "Stream (like ChatGPT)"
        case .replace:
            return "Replace All"
        }
    }
    
    var description: String {
        switch self {
        case .incremental:
            return "Add only new text incrementally"
        case .replace:
            return "Replace entire text each time"
        }
    }
}

struct AppConfiguration: Codable, Identifiable, Equatable {
    let id = UUID()
    var name: String
    var bundleIdentifier: String
    var wakeWords: [String]  // Changed to array to support multiple wake words
    var isEnabled: Bool
    var promptTemplate: String
    var autoSubmit: Bool
    var windowTitle: String?
    
    // Voice settings - nil means use global defaults
    var selectedVoiceId: String?
    var speechRate: Double?
    var voiceOutputVolume: Double?
    
    // Text input mode
    var textInputMode: TextInputMode = .incremental
    
    // Custom coding keys to handle UUID
    private enum CodingKeys: String, CodingKey {
        case name, bundleIdentifier, wakeWords, isEnabled, promptTemplate, autoSubmit, windowTitle
        case selectedVoiceId, speechRate, voiceOutputVolume, textInputMode
    }
    
    init(name: String, bundleIdentifier: String, wakeWords: [String]? = nil, iconImage: NSImage? = nil) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.wakeWords = wakeWords ?? [name]  // Use app name as default wake word
        self.isEnabled = true
        self.promptTemplate = "{input}"
        self.autoSubmit = true
        self.windowTitle = nil
        // Voice settings default to nil (use global settings)
        self.selectedVoiceId = nil
        self.speechRate = nil
        self.voiceOutputVolume = nil
    }
    
    // MARK: - Helper Methods
    
    var isInstalled: Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }
    
    var applicationURL: URL? {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }
    
    var iconImage: NSImage? {
        guard let appURL = applicationURL else { return nil }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
    
    mutating func updatePromptTemplate(_ template: String) {
        self.promptTemplate = template
    }
    
    mutating func toggle() {
        self.isEnabled.toggle()
    }
    
    var hasCustomVoiceSettings: Bool {
        return selectedVoiceId != nil || speechRate != nil || voiceOutputVolume != nil
    }
    
    // MARK: - Equatable
    
    static func == (lhs: AppConfiguration, rhs: AppConfiguration) -> Bool {
        return lhs.id == rhs.id
    }
}