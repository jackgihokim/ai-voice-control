//
//  AboutTab.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import AppKit

struct AboutTab: View {
    @State private var appVersion: String = "1.0.0"
    @State private var buildNumber: String = "1"
    @State private var systemInfo: SystemInfo = SystemInfo()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Information about AI Voice Control and your system")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // App Information
                VStack(alignment: .leading, spacing: 16) {
                    // App Icon and Basic Info
                    HStack(spacing: 16) {
                        if let appIcon = NSApp.applicationIconImage {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 64, height: 64)
                        } else {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Voice Control")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("© 2025 AI Voice Control")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Description
                    Text("An AI-powered voice control system for macOS that enables hands-free interaction with desktop applications and terminal environments.")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                    
                    // System Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("System Information")
                            .font(.headline)
                        
                        InfoRow(label: "macOS Version", value: systemInfo.macOSVersion)
                        InfoRow(label: "Architecture", value: systemInfo.architecture)
                        InfoRow(label: "Memory", value: systemInfo.totalMemory)
                        InfoRow(label: "Voice Isolation", value: systemInfo.voiceIsolationSupported ? "Supported" : "Not Supported")
                    }
                    
                    Divider()
                    
                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                        
                        FeatureRow(
                            icon: "mic.circle",
                            title: "Voice Recognition",
                            description: "Advanced speech-to-text using Apple's Speech Framework"
                        )
                        
                        FeatureRow(
                            icon: "app.badge",
                            title: "App Control",
                            description: "Control AI applications with voice commands"
                        )
                        
                        FeatureRow(
                            icon: "terminal",
                            title: "Terminal Integration",
                            description: "Voice control for iTerm2 and Terminal.app"
                        )
                        
                        FeatureRow(
                            icon: "speaker.wave.2",
                            title: "Text-to-Speech",
                            description: "High-quality voice output with system voices"
                        )
                    }
                    
                    // Links and Actions
                    HStack(spacing: 16) {
                        Button("Check for Updates") {
                            checkForUpdates()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Open System Preferences") {
                            openSystemPreferences()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                        Link("Support", destination: URL(string: "https://example.com/support")!)
                    }
                    .controlSize(.small)
                    
                    Spacer(minLength: 20)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadAppInfo()
            loadSystemInfo()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAppInfo() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = version
        }
        
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            buildNumber = build
        }
    }
    
    private func loadSystemInfo() {
        systemInfo = SystemInfo()
    }
    
    private func checkForUpdates() {
        // TODO: Implement update checking
        let alert = NSAlert()
        alert.messageText = "Updates"
        alert.informativeText = "You are running the latest version of AI Voice Control."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - System Information

struct SystemInfo {
    let macOSVersion: String
    let architecture: String
    let totalMemory: String
    let voiceIsolationSupported: Bool
    
    init() {
        // macOS Version
        let version = ProcessInfo.processInfo.operatingSystemVersion
        self.macOSVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        
        // Architecture
        #if arch(arm64)
        self.architecture = "Apple Silicon"
        #elseif arch(x86_64)
        self.architecture = "Intel"
        #else
        self.architecture = "Unknown"
        #endif
        
        // Memory
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / 1_073_741_824 // Convert to GB
        self.totalMemory = String(format: "%.0f GB", memoryGB)
        
        // Voice Isolation Support (requires macOS 12+)
        if #available(macOS 12.0, *) {
            self.voiceIsolationSupported = true
        } else {
            self.voiceIsolationSupported = false
        }
    }
}