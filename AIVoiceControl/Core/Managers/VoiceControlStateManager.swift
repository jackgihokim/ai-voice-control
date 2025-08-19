//
//  VoiceControlStateManager.swift
//  AIVoiceControl
//
//  Created by Claude on 2025-08-16.
//

import Foundation
import Combine
import SwiftUI

/// Notification names for voice control events
extension Notification.Name {
    static let voiceControlStateChanged = Notification.Name("voiceControlStateChanged")
    static let enterKeyPressed = Notification.Name("enterKeyPressed")
    static let timerWarning = Notification.Name("timerWarning")
    static let voiceRecognitionReset = Notification.Name("voiceRecognitionReset")
}

/// Single source of truth for voice control state management
@MainActor
class VoiceControlStateManager: ObservableObject {
    // MARK: - Singleton
    static let shared = VoiceControlStateManager()
    
    // MARK: - Published State
    @Published var isListening = false
    @Published var remainingTime = 58
    @Published var autoStartEnabled = true
    @Published var showFloatingTimer = true
    @Published var isTransitioning = false
    
    // MARK: - Private Properties
    private var voiceEngine: VoiceRecognitionEngine?
    private var countdownTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    let maxTime = 58
    let warningThreshold = 10
    
    // MARK: - Initialization
    private init() {
        setupNotificationObservers()
        loadUserSettings()
    }
    
    // MARK: - Public Methods
    
    /// Set the voice engine reference
    func setVoiceEngine(_ engine: VoiceRecognitionEngine) {
        self.voiceEngine = engine
    }
    
    /// Start voice listening
    func startListening() async throws {
        guard !isListening && !isTransitioning else { 
            #if DEBUG
            print("⚠️ Already listening or transitioning")
            #endif
            return 
        }
        
        isTransitioning = true
        defer { isTransitioning = false }
        
        #if DEBUG
        print("🎙️ StateManager: Starting voice recognition")
        #endif
        
        isListening = true
        
        // Start voice engine
        if let engine = voiceEngine {
            try await engine.startListening()
        }
        
        // Start countdown timer
        startCountdownTimer()
        
        // Post notification
        NotificationCenter.default.post(
            name: .voiceControlStateChanged,
            object: nil,
            userInfo: ["isListening": true]
        )
    }
    
    /// Stop voice listening
    func stopListening() {
        guard isListening && !isTransitioning else { 
            #if DEBUG
            print("⚠️ Not listening or transitioning")
            #endif
            return 
        }
        
        isTransitioning = true
        defer { isTransitioning = false }
        
        #if DEBUG
        print("🛑 StateManager: Stopping voice recognition")
        #endif
        
        isListening = false
        
        // Stop voice engine
        voiceEngine?.stopListening()
        
        // Stop countdown timer
        stopCountdownTimer()
        
        // Post reset notification to clear accumulated text and buffers
        NotificationCenter.default.post(
            name: .voiceRecognitionReset,
            object: nil,
            userInfo: ["reason": "stopListening"]
        )
        
        // Post state change notification
        NotificationCenter.default.post(
            name: .voiceControlStateChanged,
            object: nil,
            userInfo: ["isListening": false]
        )
    }
    
    /// Toggle listening state
    func toggleListening() async throws {
        if isListening {
            stopListening()
        } else {
            try await startListening()
        }
    }
    
    /// Reset the timer (stop and restart)
    func resetTimer() async {
        guard isListening else { return }
        
        #if DEBUG
        print("🔄 StateManager: Resetting timer (without clearing text)")
        #endif
        
        // Reset timer without stopping/starting voice recognition
        resetTimerOnly()
    }
    
    /// Reset only the timer without affecting voice recognition state
    func resetTimerOnly() {
        #if DEBUG
        print("⏱️ Resetting countdown timer only")
        #endif
        
        // Stop and restart timer
        stopCountdownTimer()
        startCountdownTimer()
    }
    
    /// Complete reset: stop listening, clear all text, clear app text fields, and restart listening
    func completeReset(clearTextField: Bool = true) async {
        #if DEBUG
        print("🔄 StateManager: Starting complete reset (clearTextField: \(clearTextField))")
        #endif
        
        // 1. Stop voice recognition
        stopListening()
        
        // 2. Clear all text buffers and clipboard
        await clearAllTextBuffers()
        
        // 3. Clear active app's text field (optional)
        if clearTextField {
            await clearActiveAppTextField()
        }
        
        // 4. Wait a moment before restarting
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초
        
        // 5. Restart voice recognition
        do {
            try await startListening()
            #if DEBUG
            print("✅ Complete reset successful - voice recognition restarted")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to restart voice recognition: \(error)")
            #endif
        }
    }
    
    /// Clear all text buffers and clipboard
    private func clearAllTextBuffers() async {
        #if DEBUG
        print("🧹 Clearing all text buffers and clipboard")
        #endif
        
        // Reset TextInputAutomator
        TextInputAutomator.shared.resetIncrementalText()
        
        // Clear clipboard (backup current and set empty)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Send reset notification to all components
        NotificationCenter.default.post(
            name: .voiceRecognitionReset,
            object: nil,
            userInfo: ["reason": "completeReset"]
        )
    }
    
    /// Clear active app's text field
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
        
        do {
            // Select all text (Command+A) and delete it
            try KeyboardSimulator.shared.selectAll()
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
            try KeyboardSimulator.shared.sendBackspace()
            
            #if DEBUG
            print("✅ Active app text field cleared: \(activeApp.localizedName ?? "Unknown")")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to clear active app text field: \(error)")
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    private func startCountdownTimer() {
        stopCountdownTimer()
        remainingTime = maxTime
        
        #if DEBUG
        print("⏱️ Starting countdown timer: \(maxTime) seconds")
        #endif
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                self.remainingTime -= 1
                
                // Warning notification
                if self.remainingTime == self.warningThreshold {
                    self.showWarning()
                }
                
                // Time expired (before auto-restart)
                if self.remainingTime <= 0 {
                    #if DEBUG
                    print("⏰ Timer expired - will auto-restart")
                    #endif
                    self.remainingTime = self.maxTime
                }
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        remainingTime = maxTime
        
        #if DEBUG
        print("⏹️ Countdown timer stopped")
        #endif
    }
    
    private func showWarning() {
        #if DEBUG
        print("⚠️ Warning: \(warningThreshold) seconds remaining")
        #endif
        
        NotificationCenter.default.post(
            name: .timerWarning,
            object: nil,
            userInfo: ["remainingTime": warningThreshold]
        )
    }
    
    private func loadUserSettings() {
        let settings = UserSettings.load()
        autoStartEnabled = settings.autoStartListening ?? true
        showFloatingTimer = settings.showFloatingTimer ?? true
        
        #if DEBUG
        print("📋 Loaded settings - Auto start: \(autoStartEnabled), Floating timer: \(showFloatingTimer)")
        #endif
    }
    
    private func setupNotificationObservers() {
        // Wake word detected - reset timer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWakeWordDetected),
            name: .wakeWordDetected,
            object: nil
        )
        
        // Enter key pressed - reset timer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnterKeyPressed),
            name: .enterKeyPressed,
            object: nil
        )
        
        #if DEBUG
        print("📡 Notification observers registered")
        #endif
    }
    
    @objc private func handleWakeWordDetected(_ notification: Notification) {
        #if DEBUG
        if let app = notification.userInfo?["app"] as? AppConfiguration {
            print("🎯 Wake word detected for \(app.name) - resetting timer")
        }
        #endif
        
        Task {
            await resetTimer()
        }
    }
    
    @objc private func handleEnterKeyPressed(_ notification: Notification) {
        #if DEBUG
        print("⏎ Enter key pressed - performing complete reset")
        print("   Timestamp: \(notification.userInfo?["timestamp"] as? Date ?? Date())")
        #endif
        
        Task {
            // Enter 키의 경우 텍스트 필드는 지우지 않음 (사용자가 입력을 완료했을 가능성)
            await completeReset(clearTextField: false)
        }
    }
    
    // MARK: - Deinit
    deinit {
        countdownTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}