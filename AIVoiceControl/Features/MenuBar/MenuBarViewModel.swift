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
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let permissionManager = PermissionManager.shared
    private var voiceEngine: VoiceRecognitionEngine?
    
    // MARK: - Initialization
    init() {
        setupVoiceEngine()
        setupBindings()
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
            statusMessage = transcribedText.isEmpty ? "Ready" : "Ready - Last transcription available"
            isProcessing = false
        case .starting:
            statusMessage = "Starting..."
            isProcessing = true
        case .listening:
            statusMessage = "Listening..."
            isProcessing = false
        case .processing:
            statusMessage = "Processing..."
            isProcessing = true
        case .stopping:
            statusMessage = "Stopping..."
            isProcessing = false
        }
    }
}