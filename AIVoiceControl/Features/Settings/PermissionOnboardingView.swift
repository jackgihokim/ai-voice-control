//
//  PermissionOnboardingView.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 8/4/25.
//

import SwiftUI

struct PermissionOnboardingView: View {
    @StateObject private var permissionManager = PermissionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var isCompleted = false
    
    private let permissions: [PermissionType] = [.microphone, .speechRecognition, .accessibility, .automation]
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                
                Text("Welcome to AI Voice Control")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("To get started, we need to set up some permissions for voice control to work properly.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress Indicator
            HStack(spacing: 8) {
                ForEach(0..<permissions.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                }
            }
            
            // Current Permission Step
            if !isCompleted {
                PermissionStepView(
                    permissionType: permissions[currentStep],
                    onContinue: handleContinue
                )
            } else {
                CompletionView(onFinish: {
                    dismiss()
                })
            }
            
            Spacer()
            
            // Navigation
            HStack {
                if currentStep > 0 && !isCompleted {
                    Button("Previous") {
                        currentStep = max(0, currentStep - 1)
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if !isCompleted {
                    Button("Skip Setup") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(40)
        .frame(width: 500, height: 600)
        .onAppear {
            permissionManager.updateAllPermissionStatuses()
        }
    }
    
    private func handleContinue() {
        if currentStep < permissions.count - 1 {
            currentStep += 1
        } else {
            isCompleted = true
        }
    }
}

// MARK: - Permission Step View

struct PermissionStepView: View {
    let permissionType: PermissionType
    let onContinue: () -> Void
    
    @StateObject private var permissionManager = PermissionManager.shared
    @State private var isRequesting = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Permission Icon and Title
            VStack(spacing: 16) {
                Image(systemName: permissionType.systemName)
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text(permissionType.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(permissionType.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Current Status
            HStack {
                StatusIndicator(status: currentStatus)
                Text(currentStatus.description)
                    .font(.body)
            }
            
            // Action Button
            VStack(spacing: 12) {
                if currentStatus == .notDetermined {
                    Button(action: requestPermission) {
                        HStack {
                            if isRequesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isRequesting ? "Requesting..." : "Grant Permission")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequesting)
                } else if currentStatus == .denied {
                    Button("Open System Preferences") {
                        permissionManager.openSystemPreferences(for: permissionType)
                    }
                    .buttonStyle(.borderedProminent)
                } else if currentStatus == .authorized {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Permission Granted!")
                            .foregroundColor(.green)
                    }
                    .font(.headline)
                }
                
                Button("Continue") {
                    onContinue()
                }
                .buttonStyle(.bordered)
                .opacity(shouldAllowContinue ? 1.0 : 0.5)
                .disabled(!shouldAllowContinue && currentStatus != .authorized)
            }
        }
        .onAppear {
            permissionManager.updateAllPermissionStatuses()
        }
    }
    
    private var currentStatus: PermissionStatus {
        switch permissionType {
        case .microphone:
            return permissionManager.microphonePermissionStatus
        case .speechRecognition:
            return permissionManager.speechRecognitionPermissionStatus
        case .accessibility:
            return permissionManager.accessibilityPermissionStatus  
        case .automation:
            return permissionManager.automationPermissionStatus
        }
    }
    
    private var shouldAllowContinue: Bool {
        return currentStatus == .authorized || currentStatus == .denied
    }
    
    private func requestPermission() {
        isRequesting = true
        
        Task {
            switch permissionType {
            case .microphone:
                await permissionManager.requestMicrophonePermission()
            case .speechRecognition:
                await permissionManager.requestSpeechRecognitionPermission()
            case .accessibility:
                _ = permissionManager.requestAccessibilityPermission()
            case .automation:
                _ = permissionManager.requestAutomationPermission()
            }
            
            await MainActor.run {
                isRequesting = false
            }
        }
    }
}

// MARK: - Completion View

struct CompletionView: View {
    let onFinish: () -> Void
    @StateObject private var permissionManager = PermissionManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: permissionManager.areAllCriticalPermissionsGranted() ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(permissionManager.areAllCriticalPermissionsGranted() ? .green : .orange)
            
            Text(permissionManager.areAllCriticalPermissionsGranted() ? "Setup Complete!" : "Setup Partially Complete")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(permissionManager.areAllCriticalPermissionsGranted() ? 
                 "All permissions have been granted. You can now use AI Voice Control to its full potential." :
                 "Some permissions were not granted. You can still use the app, but some features may be limited. You can grant additional permissions later in Settings.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Get Started") {
                onFinish()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    PermissionOnboardingView()
}