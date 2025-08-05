//
//  PermissionsTab.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 8/4/25.
//

import SwiftUI
import AVFoundation

struct PermissionsTab: View {
    @StateObject private var permissionManager = PermissionManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Permissions")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("AI Voice Control requires several permissions to function properly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Permission Status Overview
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: permissionManager.areAllCriticalPermissionsGranted() ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(permissionManager.areAllCriticalPermissionsGranted() ? .green : .orange)
                        
                        Text(permissionManager.areAllCriticalPermissionsGranted() ? "All required permissions granted" : "Some permissions need attention")
                            .font(.headline)
                    }
                    
                    if !permissionManager.areAllCriticalPermissionsGranted() {
                        Text("Click the buttons below to grant the necessary permissions for full functionality.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                    }
                }
                
                Divider()
                
                // Individual Permission Cards
                VStack(spacing: 16) {
                    PermissionCard(
                        type: .microphone,
                        status: permissionManager.microphonePermissionStatus,
                        onRequest: {
                            Task {
                                await permissionManager.requestMicrophonePermission()
                            }
                        },
                        onOpenSettings: {
                            permissionManager.openSystemPreferences(for: .microphone)
                        }
                    )
                    
                    PermissionCard(
                        type: .speechRecognition,
                        status: permissionManager.speechRecognitionPermissionStatus,
                        onRequest: {
                            Task {
                                await permissionManager.requestSpeechRecognitionPermission()
                            }
                        },
                        onOpenSettings: {
                            permissionManager.openSystemPreferences(for: .speechRecognition)
                        }
                    )
                    
                    PermissionCard(
                        type: .accessibility,
                        status: permissionManager.accessibilityPermissionStatus,
                        onRequest: {
                            _ = permissionManager.requestAccessibilityPermission()
                        },
                        onOpenSettings: {
                            permissionManager.openSystemPreferences(for: .accessibility)
                        }
                    )
                    
                    PermissionCard(
                        type: .automation,
                        status: permissionManager.automationPermissionStatus,
                        onRequest: {
                            _ = permissionManager.requestAutomationPermission()
                        },
                        onOpenSettings: {
                            permissionManager.openSystemPreferences(for: .automation)
                        }
                    )
                }
                
                Divider()
                
                // Refresh Button
                HStack {
                    Button("Refresh Status") {
                        permissionManager.updateAllPermissionStatuses()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Open Security & Privacy") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Debug info in development builds
                #if DEBUG
                VStack(alignment: .leading, spacing: 8) {
                    Text("Debug Info")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    
                    if let executablePath = Bundle.main.executablePath {
                        Text("Executable: \(executablePath)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    
                    Text("Raw Mic Status: \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Force Refresh All") {
                            permissionManager.updateAllPermissionStatuses()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Test Mic Request") {
                            Task {
                                let result = await permissionManager.requestMicrophonePermission()
                                print("🎤 Test request result: \(result)")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.top)
                #endif
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            permissionManager.updateAllPermissionStatuses()
        }
    }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let type: PermissionType
    let status: PermissionStatus
    let onRequest: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: type.systemName)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue)
                        .font(.headline)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusIndicator(status: status)
            }
            
            HStack {
                Text(status.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                switch status {
                case .notDetermined:
                    Button("Request Permission") {
                        onRequest()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                case .denied:
                    VStack(spacing: 4) {
                        Button("Open Settings") {
                            onOpenSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Text("Grant permission in System Settings")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                case .authorized:
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Granted")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        
                        Text("Permission active")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                case .restricted:
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Restricted")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                        
                        Text("Cannot be granted")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let status: PermissionStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(status.rawValue)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .authorized:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        }
    }
}

#Preview {
    PermissionsTab()
        .frame(width: 600, height: 500)
}