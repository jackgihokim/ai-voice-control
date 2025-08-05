//
//  MenuBarViewModel.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import Combine

@MainActor
class MenuBarViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isListening: Bool = false
    @Published var transcribedText: String = ""
    @Published var statusMessage: String = "Ready"
    @Published var isProcessing: Bool = false
    @Published var hasRequiredPermissions: Bool = false
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let permissionManager = PermissionManager.shared
    
    // MARK: - Initialization
    init() {
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
    private func setupBindings() {
        // Setup any necessary bindings or observers
        $isListening
            .sink { [weak self] listening in
                self?.updateStatusMessage(listening: listening)
            }
            .store(in: &cancellables)
        
        // Monitor permission changes (removed to prevent infinite loops)
        // Will be manually updated when needed
    }
    
    private func startListening() {
        statusMessage = "Listening..."
        isProcessing = true
        
        // TODO: Implement actual voice recording and processing
        // For now, just simulate with a delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                self.transcribedText = "Sample transcribed text..."
                self.statusMessage = "Processing complete"
                self.isProcessing = false
                self.isListening = false
            }
        }
    }
    
    private func stopListening() {
        statusMessage = "Stopped"
        isProcessing = false
        
        // TODO: Stop actual recording
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
}