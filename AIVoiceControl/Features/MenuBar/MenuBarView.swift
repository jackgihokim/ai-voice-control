//
//  MenuBarView.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @State private var showingPermissionOnboarding = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main Content
            ScrollView {
                VStack(spacing: 16) {
                    // Permission Status (if not granted)
                    if !viewModel.hasRequiredPermissions {
                        permissionStatusSection
                    }
                    
                    // Status Section
                    statusSection
                    
                    // Control Section
                    controlSection
                    
                    // Transcription Section
                    if !viewModel.transcribedText.isEmpty {
                        transcriptionSection
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            footerView
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 300, height: 400)
        .sheet(isPresented: $showingPermissionOnboarding) {
            PermissionOnboardingView()
        }
    }
    
    // MARK: - Permission Status Section
    private var permissionStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Setup Required")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
                Spacer()
            }
            
            Text("Some permissions are missing for voice control to work properly.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Complete Setup") {
                showingPermissionOnboarding = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Image(systemName: "mic.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text("AI Voice Control")
                .font(.headline)
            
            Spacer()
            
            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Status Section
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Status", systemImage: "info.circle")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.statusMessage)
                    .font(.body)
                
                Spacer()
                
                if viewModel.isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
    }
    
    // MARK: - Control Section
    private var controlSection: some View {
        VStack(spacing: 12) {
            // Language selector
            HStack {
                Text("Language:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $viewModel.currentLanguage) {
                    Text("한국어").tag(VoiceLanguage.korean)
                    Text("English").tag(VoiceLanguage.english)
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isListening)
            }
            
            // Main control button
            Button(action: viewModel.toggleListening) {
                HStack {
                    Image(systemName: viewModel.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                    
                    Text(viewModel.isListening ? "Stop Listening" : "Start Listening")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.isListening ? Color.red : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing && !viewModel.isListening || !viewModel.hasRequiredPermissions)
            
            // Timer display when listening
            if viewModel.isListening {
                timerDisplay
            }
            
            // Audio level indicator
            if viewModel.isListening {
                audioLevelIndicator
            }
            
            // Secondary actions
            HStack(spacing: 8) {
                Button(action: viewModel.clearTranscription) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.transcribedText.isEmpty)
                
                Spacer()
                
                Button(action: viewModel.openSettings) {
                    Label("Settings", systemImage: "gear")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - Transcription Section
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Last Transcription", systemImage: "text.alignleft")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(viewModel.transcribedText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }
            .frame(maxHeight: 100)
            
            HStack {
                Button(action: copyTranscription) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            Text("Press ⌘K to toggle listening")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Properties
    private var statusColor: Color {
        if viewModel.isListening {
            return .red
        } else if viewModel.isProcessing {
            return .orange
        } else {
            return .green
        }
    }
    
    // MARK: - Timer Display
    private var timerDisplay: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(timerColor)
                
                Text("Auto-restart in \(viewModel.remainingTime)s")
                    .font(.caption)
                    .foregroundColor(timerColor)
                
                Spacer()
                
                // Refresh button
                Button(action: {
                    Task {
                        await viewModel.refreshListening()
                    }
                }) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundColor(.primary)
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!viewModel.isListening)
            }
            
            ProgressView(value: Double(viewModel.remainingTime), total: 59)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(timerColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
    
    private var timerColor: Color {
        if viewModel.remainingTime <= 10 {
            return .red
        } else if viewModel.remainingTime <= 30 {
            return .orange
        } else {
            return .green
        }
    }
    
    // MARK: - Audio Level Indicator
    private var audioLevelIndicator: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(0..<20) { index in
                    Rectangle()
                        .fill(audioLevelColor(for: index))
                        .frame(width: 8, height: 20)
                        .scaleEffect(y: audioLevelScale(for: index), anchor: .bottom)
                        .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
                }
            }
            
            Text("Audio Level")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private func audioLevelScale(for index: Int) -> CGFloat {
        let normalizedIndex = CGFloat(index) / 20.0
        return CGFloat(viewModel.audioLevel) > normalizedIndex ? 1.0 : 0.3
    }
    
    private func audioLevelColor(for index: Int) -> Color {
        let normalizedIndex = CGFloat(index) / 20.0
        if normalizedIndex < 0.6 {
            return .green
        } else if normalizedIndex < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
    
    // MARK: - Helper Methods
    private func copyTranscription() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.transcribedText, forType: .string)
    }
}

// MARK: - Preview
#Preview {
    MenuBarView(viewModel: MenuBarViewModel())
}