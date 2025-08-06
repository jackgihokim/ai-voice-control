//
//  MenuBarViewModel.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import Combine
import Speech

@MainActor
class MenuBarViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isListening: Bool = false
    @Published var transcribedText: String = ""
    @Published var statusMessage: String = "Ready"
    @Published var isProcessing: Bool = false
    @Published var hasRequiredPermissions: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var currentLanguage: VoiceLanguage = .korean
    @Published var isWaitingForCommand: Bool = false
    @Published var detectedApp: AppConfiguration?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let permissionManager = PermissionManager.shared
    private var voiceEngine: VoiceRecognitionEngine?
    
    // MARK: - Initialization
    init() {
        setupVoiceEngine()
        setupBindings()
        setupNotificationObservers()
        checkPermissions()
    }
    
    // MARK: - Public Methods
    func toggleListening() {
        // Check permissions before starting
        if !hasRequiredPermissions {
            statusMessage = "Permissions required"
            return
        }
        
        isListening.toggle()
        
        if isListening {
            startListening()
        } else {
            stopListening()
        }
    }
    
    func checkPermissions() {
        permissionManager.updateAllPermissionStatuses()
        hasRequiredPermissions = permissionManager.areAllCriticalPermissionsGranted()
        
        if !hasRequiredPermissions {
            statusMessage = "Setup required - Check permissions"
        } else {
            statusMessage = "Ready"
        }
    }
    
    func clearTranscription() {
        transcribedText = ""
        statusMessage = "Ready"
    }
    
    func openSettings() {
        // Post notification to AppDelegate to open settings
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
    
    // MARK: - Private Methods
    private func setupVoiceEngine() {
        let locale = currentLanguage == .korean ? Locale(identifier: "ko-KR") : Locale(identifier: "en-US")
        voiceEngine = VoiceRecognitionEngine(locale: locale)
        
        // Bind voice engine properties
        voiceEngine?.$isListening
            .receive(on: DispatchQueue.main)
            .sink { [weak self] listening in
                self?.isListening = listening
            }
            .store(in: &cancellables)
        
        voiceEngine?.$currentTranscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.transcribedText = text
            }
            .store(in: &cancellables)
        
        voiceEngine?.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.audioLevel = level
            }
            .store(in: &cancellables)
        
        voiceEngine?.$recognitionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateStatusForRecognitionState(state)
            }
            .store(in: &cancellables)
        
        voiceEngine?.$error
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.statusMessage = error.localizedDescription
            }
            .store(in: &cancellables)
        
        voiceEngine?.$isWaitingForCommand
            .receive(on: DispatchQueue.main)
            .sink { [weak self] waiting in
                self?.isWaitingForCommand = waiting
            }
            .store(in: &cancellables)
        
        voiceEngine?.$detectedApp
            .receive(on: DispatchQueue.main)
            .sink { [weak self] app in
                self?.detectedApp = app
            }
            .store(in: &cancellables)
    }
    
    private func setupBindings() {
        // Monitor language changes
        $currentLanguage
            .dropFirst()
            .sink { [weak self] language in
                let locale = language == .korean ? Locale(identifier: "ko-KR") : Locale(identifier: "en-US")
                self?.voiceEngine?.switchLanguage(to: locale)
            }
            .store(in: &cancellables)
        
        // Monitor permission changes automatically
        permissionManager.$microphonePermissionStatus
            .combineLatest(permissionManager.$speechRecognitionPermissionStatus)
            .sink { [weak self] micStatus, speechStatus in
                let newPermissionStatus = (micStatus == .authorized && speechStatus == .authorized)
                
                if self?.hasRequiredPermissions != newPermissionStatus {
                    self?.hasRequiredPermissions = newPermissionStatus
                    
                    if newPermissionStatus {
                        self?.statusMessage = "Ready"
                        #if DEBUG
                        print("✅ Permissions granted - UI updated automatically")
                        #endif
                    } else {
                        self?.statusMessage = "Setup required - Check permissions"
                        #if DEBUG
                        print("⚠️ Permissions missing - UI updated automatically")
                        #endif
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func startListening() {
        Task {
            do {
                try await voiceEngine?.startListening()
            } catch {
                statusMessage = "Failed to start: \(error.localizedDescription)"
                isListening = false
                isProcessing = false
            }
        }
    }
    
    private func stopListening() {
        voiceEngine?.stopListening()
    }
    
    private func updateStatusMessage(listening: Bool) {
        if listening {
            statusMessage = "Listening..."
        } else if !transcribedText.isEmpty {
            statusMessage = "Ready - Last transcription available"
        } else {
            statusMessage = "Ready"
        }
    }
    
    private func updateStatusForRecognitionState(_ state: VoiceRecognitionEngine.RecognitionState) {
        switch state {
        case .idle:
            if isWaitingForCommand, let app = detectedApp {
                statusMessage = "Say command for \(app.name) and 'Execute'"
            } else {
                statusMessage = transcribedText.isEmpty ? "Ready" : "Ready - Last transcription available"
            }
            isProcessing = false
        case .starting:
            statusMessage = "Starting..."
            isProcessing = true
        case .listening:
            if isWaitingForCommand, let app = detectedApp {
                statusMessage = "Listening for \(app.name) command..."
            } else {
                statusMessage = "Listening..."
            }
            isProcessing = false
        case .processing:
            statusMessage = "Processing..."
            isProcessing = true
        case .stopping:
            statusMessage = "Stopping..."
            isProcessing = false
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWakeWordDetected(_:)),
            name: .wakeWordDetected,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCommandReady(_:)),
            name: .commandReady,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCommandTimeout),
            name: .commandTimeout,
            object: nil
        )
    }
    
    @objc private func handleWakeWordDetected(_ notification: Notification) {
        guard let app = notification.userInfo?["app"] as? AppConfiguration else { return }
        
        #if DEBUG
        print("🎯 Wake word detected for: \(app.name)")
        print("   Bundle ID: \(app.bundleIdentifier)")
        
        // Check current frontmost app before activation
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            print("   Currently active app: \(frontApp.localizedName ?? "Unknown") (\(frontApp.bundleIdentifier ?? "Unknown"))")
        }
        #endif
        
        // Activate the app when wake word is detected
        let activated = AppActivator.shared.activateApp(app)
        
        #if DEBUG
        // Check frontmost app after activation attempt
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            print("   After activation - Active app: \(frontApp.localizedName ?? "Unknown") (\(frontApp.bundleIdentifier ?? "Unknown"))")
        }
        #endif
        
        if activated {
            statusMessage = "Activated \(app.name) - Say command"
        } else {
            statusMessage = "Wake word detected: \(app.name)"
        }
        
        #if DEBUG
        if !activated {
            print("⚠️ Could not activate \(app.name)")
        } else {
            print("✅ Successfully handled wake word for \(app.name)")
        }
        #endif
        
        // 웨이크 워드로 앱을 활성화한 후 즉시 다음 웨이크 워드를 받을 수 있게 빠르게 리셋
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            #if DEBUG
            print("🔄 MenuBarViewModel: Resetting for next wake word...")
            #endif
            self.voiceEngine?.resetWakeWordState()
            self.statusMessage = "Ready - Listening for next wake word"
            
            #if DEBUG
            print("✅ MenuBarViewModel: Ready for next wake word")
            #endif
        }
    }
    
    @objc private func handleCommandReady(_ notification: Notification) {
        guard let app = notification.userInfo?["app"] as? AppConfiguration,
              let command = notification.userInfo?["command"] as? String else { return }
        
        // Ensure the app is still in focus
        AppActivator.shared.bringAppToFront(app)
        
        statusMessage = "Executing: \(command)"
        #if DEBUG
        print("✅ Command ready for \(app.name): \(command)")
        print("📝 Command text: '\(command)'")
        #endif
        
        // TODO: Step 7-8에서 실제 텍스트 입력 구현
        // For now, just ensure the app is activated and ready
    }
    
    @objc private func handleCommandTimeout() {
        statusMessage = "Command timeout - Ready"
    }
}