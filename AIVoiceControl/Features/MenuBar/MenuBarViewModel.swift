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
    @Published var remainingTime: Int = 59
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let permissionManager = PermissionManager.shared
    private var voiceEngine: VoiceRecognitionEngine?
    private let stateManager = VoiceControlStateManager.shared
    
    // MARK: - Public Properties for StateManager Integration
    var voiceRecognitionEngine: VoiceRecognitionEngine? {
        return voiceEngine
    }
    
    // MARK: - Initialization
    init() {
        setupVoiceEngine()
        setupBindings()
        setupStateManagerBindings()
        setupNotificationObservers()
        checkPermissions()
    }
    
    // MARK: - Public Methods
    func refreshListening() async {
        await stateManager.refreshListening()
    }
    
    func toggleListening() {
        // Check permissions before starting
        if !hasRequiredPermissions {
            statusMessage = "Permissions required"
            return
        }
        
        Task {
            do {
                try await stateManager.toggleListening()
            } catch {
                statusMessage = "Failed to toggle: \(error.localizedDescription)"
            }
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
                
                // 실시간 텍스트 입력은 이제 handleCommandBufferUpdated에서 처리됨
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
                    } else {
                        self?.statusMessage = "Setup required - Check permissions"
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupStateManagerBindings() {
        // Subscribe to StateManager's published properties
        stateManager.$isListening
            .assign(to: &$isListening)
        
        stateManager.$remainingTime
            .assign(to: &$remainingTime)
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
            selector: #selector(handleCommandBufferUpdated(_:)),
            name: .commandBufferUpdated,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceRecognitionReset(_:)),
            name: .voiceRecognitionReset,
            object: nil
        )
    }
    
    @objc private func handleWakeWordDetected(_ notification: Notification) {
        guard let app = notification.userInfo?["app"] as? AppConfiguration else { return }
        
        
        // 새로운 앱이 활성화되므로 증분 텍스트 리셋
        TextInputAutomator.shared.resetIncrementalText()
        
        // Activate the app when wake word is detected
        let activated = AppActivator.shared.activateApp(app)
        
        
        if activated {
            statusMessage = "Activated \(app.name) - Say command"
        } else {
            statusMessage = "Wake word detected: \(app.name)"
        }
        
        
        // 웨이크 워드로 앱이 활성화되면 명령 대기 상태 유지
        // resetWakeWordState()를 호출하지 않음 - 명령이 입력될 때까지 대기
    }
    
    @objc private func handleCommandReady(_ notification: Notification) {
        guard let app = notification.userInfo?["app"] as? AppConfiguration,
              let command = notification.userInfo?["command"] as? String else { return }
        
        // Ensure the app is still in focus
        AppActivator.shared.bringAppToFront(app)
        
        statusMessage = "Executing: \(command)"
        
        // Step 8: 실제 텍스트 입력 구현
        Task {
            // 앱이 완전히 활성화될 때까지 잠시 대기
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5초
            
            
            let success = await AppActivator.shared.inputTextToCurrentApp(command, submitText: false)
            
            if success {
                statusMessage = "Text input successful for \(app.name)"
            } else {
                statusMessage = "Text input failed for \(app.name)"
            }
            
            // 상태 메시지를 잠시 후 리셋
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.statusMessage = "Ready - Listening for next wake word"
            }
        }
    }
    
    @objc private func handleCommandBufferUpdated(_ notification: Notification) {
        guard let app = notification.userInfo?["app"] as? AppConfiguration,
              let text = notification.userInfo?["text"] as? String else { 
            return 
        }
        
        
        // 앱의 입력 모드에 따라 다른 방식으로 처리
        switch app.textInputMode {
        case .incremental:
            // 증분 방식: 차이점만 추가
            Task {
                do {
                    let cleanText = removeWakeWords(text, from: app)
                    
                    if !cleanText.isEmpty {
                        try TextInputAutomator.shared.inputTextIncremental(cleanText)
                        statusMessage = "Streaming to \(app.name)..."
                    }
                } catch {
                    statusMessage = "Incremental input failed for \(app.name): \(error.localizedDescription)"
                }
            }
            
        case .replace:
            // 교체 방식: 전체 텍스트 교체 (기존 Claude 스타일)
            let cleanText = removeWakeWords(text, from: app)
            
            if !cleanText.isEmpty {
                let success = AppActivator.shared.replaceTextInCurrentApp(cleanText)
                
                if !success {
                    statusMessage = "Text input failed for \(app.name)"
                }
            }
        }
    }
    
    @objc private func handleVoiceRecognitionReset(_ notification: Notification) {
        let reason = notification.userInfo?["reason"] as? String ?? "unknown"
        
        // Clear all transcribed text
        transcribedText = ""
        
        // Reset status message
        statusMessage = "Ready"
    }
    
    private func removeWakeWords(_ text: String, from app: AppConfiguration) -> String {
        var cleanText = text
        
        // 웨이크 워드들을 제거
        for wakeWord in app.wakeWords {
            // 대소문자 구분 없이 제거, 처음 나타나는 것만
            if let range = cleanText.range(of: wakeWord, options: [.caseInsensitive]) {
                cleanText.removeSubrange(range)
                break // 첫 번째 매칭만 제거
            }
        }
        
        return cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}