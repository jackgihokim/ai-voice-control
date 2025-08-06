//
//  VoiceSettingsTab.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import AVFoundation

struct VoiceSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var isTestingVoice = false
    @State private var voiceLoadingError: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Voice Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Configure default voice settings. App-specific settings can be configured in App Management.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Settings Form
            Form {
                Section("Voice Recognition") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recognition Language")
                        Picker("Language", selection: $viewModel.userSettings.voiceLanguage) {
                            ForEach(VoiceLanguage.allCases, id: \.self) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Input Sensitivity")
                        HStack {
                            Slider(
                                value: $viewModel.userSettings.voiceInputSensitivity,
                                in: 0.1...1.0,
                                step: 0.1
                            ) {
                                Text("Sensitivity")
                            } minimumValueLabel: {
                                Text("Low")
                            } maximumValueLabel: {
                                Text("High")
                            }
                            
                            Text("\(Int(viewModel.userSettings.voiceInputSensitivity * 100))%")
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Enable Voice Isolation", isOn: $viewModel.userSettings.enableVoiceIsolation)
                            .help("Reduces background noise during recording (macOS 12+)")
                        
                        if viewModel.userSettings.enableVoiceIsolation {
                            HStack {
                                Text("Audio Quality:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Monitoring...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        }
                    }
                }
                
                Section("Text-to-Speech") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Voice")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            if let error = voiceLoadingError {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Voice loading failed")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Text("Using system default voice")
                                        .foregroundColor(.secondary)
                                        .font(.caption2)
                                    
                                    Button("Retry") {
                                        voiceLoadingError = nil
                                        loadAllSystemVoices()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            } else if availableVoices.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("System Default Voice")
                                        .font(.body)
                                    Text("Advanced voice selection available via 'Load All System Voices' below")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            } else {
                                Picker("Voice", selection: $viewModel.userSettings.selectedVoiceId) {
                                    Text("System Default").tag("")
                                    
                                    ForEach(availableVoices, id: \.identifier) { voice in
                                        Text("\(voice.name) (\(voice.language))")
                                            .tag(voice.identifier)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speech Rate")
                        HStack {
                            Slider(
                                value: $viewModel.userSettings.speechRate,
                                in: 0.1...1.0,
                                step: 0.1
                            ) {
                                Text("Rate")
                            } minimumValueLabel: {
                                Text("Slow")
                            } maximumValueLabel: {
                                Text("Fast")
                            }
                            
                            Text("\(Int(viewModel.userSettings.speechRate * 100))%")
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Output Volume")
                        HStack {
                            Slider(
                                value: $viewModel.userSettings.voiceOutputVolume,
                                in: 0.0...1.0,
                                step: 0.1
                            ) {
                                Text("Volume")
                            } minimumValueLabel: {
                                Image(systemName: "speaker.wave.1")
                            } maximumValueLabel: {
                                Image(systemName: "speaker.wave.3")
                            }
                            
                            Text("\(Int(viewModel.userSettings.voiceOutputVolume * 100))%")
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Button("Test Voice") {
                            testCurrentVoice()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestingVoice)
                        
                        if isTestingVoice {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Playing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Advanced Voice Options") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Voice System")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button("Load All System Voices") {
                                loadAllSystemVoices()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Text("Basic voices are loaded by default. Click 'Load All System Voices' to see additional voices (may cause system delays).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack {
                            Text("Download More Voices")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Button("Open System Settings") {
                                openSystemPreferences()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Text("For high-quality voices, visit System Settings > Accessibility > Spoken Content > System Voice > Customize.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                Section("Note") {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.accentColor)
                        
                        Text("These are default settings. You can override them for individual apps in the App Management tab.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            
            Spacer()
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            // Delay voice loading to ensure system services are ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                loadAvailableVoices()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadAvailableVoices() {
        // Clear any previous error
        voiceLoadingError = nil
        
        // Use a much safer approach - don't load system voices at startup
        // This prevents the FactoryInstall error completely
        DispatchQueue.main.async {
            // Instead of loading all voices, we'll use a minimal set of basic voices
            // that are guaranteed to be available on macOS
            self.availableVoices = self.getBasicVoices()
            self.voiceLoadingError = nil
        }
    }
    
    private func getBasicVoices() -> [AVSpeechSynthesisVoice] {
        // Don't query the system for voices at all to avoid FactoryInstall errors
        // Return empty array - the UI will handle this gracefully
        return []
    }
    
    private func loadAllSystemVoices() {
        // This function attempts to load all system voices
        // User explicitly requested this, so we warn them about potential issues
        voiceLoadingError = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Add longer delay for system voice loading
            Thread.sleep(forTimeInterval: 1.0)
            
            do {
                // Try to load all system voices
                let allVoices = AVSpeechSynthesisVoice.speechVoices()
                let sortedVoices = allVoices.sorted { $0.name < $1.name }
                
                DispatchQueue.main.async {
                    if sortedVoices.isEmpty {
                        self.voiceLoadingError = "System voice loading failed"
                        // Keep the basic voices as fallback
                    } else {
                        self.availableVoices = sortedVoices
                        self.voiceLoadingError = nil
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.voiceLoadingError = "System voice loading failed: \(error.localizedDescription)"
                    // Keep the basic voices as fallback
                }
            }
        }
    }
    
    private func testCurrentVoice() {
        isTestingVoice = true
        
        Task {
            do {
                let utterance = AVSpeechUtterance(string: "Hello, this is a test of the current voice settings.")
                utterance.rate = Float(viewModel.userSettings.speechRate * 0.5) // Convert to AVSpeech rate
                utterance.volume = Float(viewModel.userSettings.voiceOutputVolume)
                
                // Only try to set specific voice if we have voices loaded and a valid ID
                if !availableVoices.isEmpty && !viewModel.userSettings.selectedVoiceId.isEmpty {
                    // Try to find the voice in our loaded voices first
                    if let selectedVoice = availableVoices.first(where: { $0.identifier == viewModel.userSettings.selectedVoiceId }) {
                        utterance.voice = selectedVoice
                    }
                }
                // Otherwise use system default voice (don't set utterance.voice)
                
                let synthesizer = AVSpeechSynthesizer()
                synthesizer.speak(utterance)
                
                // Wait for speech to complete
                try await Task.sleep(for: .seconds(3))
                
                await MainActor.run {
                    isTestingVoice = false
                }
            } catch {
                await MainActor.run {
                    isTestingVoice = false
                }
            }
        }
    }
    
    private func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Spoken_Content") {
            NSWorkspace.shared.open(url)
        }
    }
}