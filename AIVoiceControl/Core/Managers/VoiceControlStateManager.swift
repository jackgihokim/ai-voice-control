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
    @Published var remainingTime = 59
    @Published var autoStartEnabled = true
    @Published var showFloatingTimer = true
    @Published var isTransitioning = false
    
    // Flag to prevent UI updates during text field operations
    var isPerformingTextFieldOperation = false
    
    // MARK: - Private Properties
    private var voiceEngine: VoiceRecognitionEngine?
    private var countdownTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    let maxTime = 59
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
            let activeApp = NSWorkspace.shared.frontmostApplication
            print("⚠️ [TIMER-DEBUG] Already listening or transitioning - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
            #endif
            return 
        }
        
        let activeApp = NSWorkspace.shared.frontmostApplication
        #if DEBUG
        print("🎙️ [TIMER-DEBUG] Starting voice recognition - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
        #endif
        
        isTransitioning = true
        defer { isTransitioning = false }
        
        
        isListening = true
        
        // Start voice engine
        if let engine = voiceEngine {
            try await engine.startListening()
            #if DEBUG
            print("🎤 [TIMER-DEBUG] Voice engine started successfully")
            #endif
        } else {
            #if DEBUG
            print("❌ [TIMER-DEBUG] Voice engine is nil!")
            #endif
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
            let activeApp = NSWorkspace.shared.frontmostApplication
            print("⚠️ [TIMER-DEBUG] Not listening or transitioning - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
            #endif
            return 
        }
        
        let activeApp = NSWorkspace.shared.frontmostApplication
        #if DEBUG
        print("🛑 [TIMER-DEBUG] Stopping voice recognition - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
        #endif
        
        isTransitioning = true
        defer { isTransitioning = false }
        
        
        isListening = false
        
        // Stop voice engine
        voiceEngine?.stopListening()
        #if DEBUG
        print("🎤 [TIMER-DEBUG] Voice engine stopped")
        #endif
        
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
        
        let activeApp = NSWorkspace.shared.frontmostApplication
        #if DEBUG
        print("🔄 [TIMER-DEBUG] Resetting timer (without clearing text) - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
        #endif
        
        // Reset timer without stopping/starting voice recognition
        resetTimerOnly()
    }
    
    /// Refresh listening by doing a complete reset
    func refreshListening() async {
        let activeApp = NSWorkspace.shared.frontmostApplication
        #if DEBUG
        print("🔄 [TIMER-DEBUG] Refreshing voice recognition - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
        #endif
        
        // 음성 인식 리프레시 시 텍스트 필드도 클리어
        await completeReset(clearTextField: true)
    }
    
    /// Reset only the timer without affecting voice recognition state
    func resetTimerOnly() {
        let activeApp = NSWorkspace.shared.frontmostApplication
        #if DEBUG
        print("⏱️ [TIMER-DEBUG] Resetting countdown timer only - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
        #endif
        
        // Stop and restart timer
        stopCountdownTimer()
        startCountdownTimer()
    }
    
    /// Complete reset: stop listening, clear all text, clear app text fields, and restart listening
    func completeReset(clearTextField: Bool = true) async {
        let activeApp = NSWorkspace.shared.frontmostApplication
        #if DEBUG
        print("🔄 [TIMER-DEBUG] Starting complete reset (clearTextField: \(clearTextField)) - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
        print("    Current state: isListening=\(isListening), isTransitioning=\(isTransitioning)")
        print("    Voice engine state: \(voiceEngine?.isListening ?? false)")
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
            print("✅ [TIMER-DEBUG] Complete reset successful - voice recognition restarted")
            print("    Final state: isListening=\(isListening), isTransitioning=\(isTransitioning)")
            print("    Voice engine state: \(voiceEngine?.isListening ?? false)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [TIMER-DEBUG] Failed to restart voice recognition: \(error)")
            print("    Failed state: isListening=\(isListening), isTransitioning=\(isTransitioning)")
            print("    Voice engine state: \(voiceEngine?.isListening ?? false)")
            #endif
        }
    }
    
    /// Clear all text buffers and clipboard
    private func clearAllTextBuffers() async {
        
        // WakeWordDetector 상태는 유지 (웨이크워드 감지 후 명령 대기 상태 유지)
        // voiceEngine?.resetWakeWordState() <- 제거: 명령 입력 상태를 유지해야 함
        
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
        
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            return
        }
        
        do {
            // Select all text (Command+A)
            try KeyboardSimulator.shared.selectAll()
            
            
            // 텍스트 선택 완료 대기
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
            
            
            // 백스페이스 한 번으로 선택된 텍스트 삭제
            try KeyboardSimulator.shared.sendBackspace()
            
        } catch {
        }
    }
    
    // MARK: - Private Methods
    
    func startCountdownTimer() {
        stopCountdownTimer()
        remainingTime = maxTime
        
        let activeApp = NSWorkspace.shared.frontmostApplication
        #if DEBUG
        print("⏱️ [TIMER-DEBUG] Starting countdown timer: \(maxTime)s - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
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
                    let activeApp = NSWorkspace.shared.frontmostApplication
                    print("⏰ [TIMER-DEBUG] Timer expired - will auto-restart - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
                    print("    Timer state: isListening=\(self.isListening), isTransitioning=\(self.isTransitioning)")
                    print("    Voice engine state: \(self.voiceEngine?.isListening ?? false)")
                    #endif
                    self.remainingTime = self.maxTime
                }
            }
        }
    }
    
    func stopCountdownTimer() {
        let wasRunning = countdownTimer != nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        // UI 업데이트를 방지하는 플래그가 설정되어 있지 않을 때만 업데이트
        if !isPerformingTextFieldOperation {
            remainingTime = maxTime
        }
        
        #if DEBUG
        if wasRunning {
            let activeApp = NSWorkspace.shared.frontmostApplication
            print("⏹️ [TIMER-DEBUG] Countdown timer stopped - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
            print("    UI update prevented: \(isPerformingTextFieldOperation)")
        }
        #endif
    }
    
    private func showWarning() {
        let activeApp = NSWorkspace.shared.frontmostApplication
        #if DEBUG
        print("⚠️ [TIMER-DEBUG] Warning: \(warningThreshold) seconds remaining - App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
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
        
        // Voice engine restarted - restart timer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceEngineRestarted),
            name: .voiceEngineRestarted,
            object: nil
        )
        
        // Timer expired reset - delegate from voice engine
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimerExpiredReset),
            name: .timerExpiredReset,
            object: nil
        )
        
    }
    
    @objc private func handleWakeWordDetected(_ notification: Notification) {
        let activeApp = NSWorkspace.shared.frontmostApplication
        #if DEBUG
        if let app = notification.userInfo?["app"] as? AppConfiguration {
            print("🎯 [TIMER-DEBUG] Wake word detected for \(app.name) - performing complete reset - Active App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
        }
        #endif
        
        Task {
            // 웨이크워드 감지 시 음성인식 완전 리셋 (텍스트 필드는 유지)
            await completeReset(clearTextField: false)
        }
    }
    
    @objc private func handleEnterKeyPressed(_ notification: Notification) {
        let activeApp = NSWorkspace.shared.frontmostApplication
        #if DEBUG
        print("⏎ [TIMER-DEBUG] Enter key pressed - performing complete reset - Active App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
        print("   Timestamp: \(notification.userInfo?["timestamp"] as? Date ?? Date())")
        #endif
        
        Task {
            // Enter 키의 경우 텍스트 필드는 지우지 않음 (사용자가 입력을 완료했을 가능성)
            await completeReset(clearTextField: false)
        }
    }
    
    @objc private func handleVoiceEngineRestarted(_ notification: Notification) {
        let activeApp = NSWorkspace.shared.frontmostApplication
        let reason = notification.userInfo?["reason"] as? String ?? "unknown"
        
        #if DEBUG
        print("🔄 [TIMER-DEBUG] Voice engine restarted (\(reason)) - restarting timer - Active App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
        print("   Current timer state: isListening=\(isListening), remainingTime=\(remainingTime)")
        #endif
        
        // Only restart timer if we're in listening mode but timer isn't running
        if isListening && countdownTimer == nil {
            #if DEBUG
            print("⏰ [TIMER-DEBUG] Timer was missing - restarting countdown timer")
            #endif
            startCountdownTimer()
        }
    }
    
    @objc private func handleTimerExpiredReset(_ notification: Notification) {
        let activeApp = NSWorkspace.shared.frontmostApplication
        let reason = notification.userInfo?["reason"] as? String ?? "unknown"
        let clearTextField = notification.userInfo?["clearTextField"] as? Bool ?? false
        let sourceEngine = notification.userInfo?["sourceEngine"] as? String ?? "unknown"
        
        #if DEBUG
        print("⏰ [TIMER-DEBUG] Timer expired reset from \(sourceEngine) - performing complete reset - Active App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
        print("   Reason: \(reason), clearTextField: \(clearTextField)")
        print("   Current state: isListening=\(isListening), isTransitioning=\(isTransitioning)")
        #endif
        
        Task {
            // Perform complete reset through StateManager to ensure UI updates
            await completeReset(clearTextField: clearTextField)
        }
    }
    
    // MARK: - Deinit
    deinit {
        countdownTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}