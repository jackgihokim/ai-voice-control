//
//  GeneralSettingsTab.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI

struct GeneralSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("General Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Configure basic application behavior")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Settings Form
            Form {
                Section("Startup") {
                    Toggle("Launch at login", isOn: $viewModel.userSettings.launchAtLogin)
                    Toggle("Auto-start listening", isOn: Binding(
                        get: { viewModel.userSettings.autoStartListening ?? false },
                        set: { viewModel.userSettings.autoStartListening = $0 }
                    ))
                    .help("Automatically start voice recognition when the app launches")
                }
                
                Section("Interface") {
                    Toggle("Show menu bar icon", isOn: $viewModel.userSettings.showMenuBarIcon)
                    Toggle("Enable notifications", isOn: $viewModel.userSettings.enableNotifications)
                }
                
                Section("Voice Control Automation") {
                    Toggle("Show floating timer", isOn: Binding(
                        get: { viewModel.userSettings.showFloatingTimer ?? true },
                        set: { viewModel.userSettings.showFloatingTimer = $0 }
                    ))
                    .help("Display a floating timer showing remaining time")
                    
                    Toggle("Reset timer on wake word", isOn: Binding(
                        get: { viewModel.userSettings.resetOnWakeWord ?? true },
                        set: { viewModel.userSettings.resetOnWakeWord = $0 }
                    ))
                    .help("Reset 58-second timer when wake word is detected")
                    
                    Toggle("Reset timer on Enter key", isOn: Binding(
                        get: { viewModel.userSettings.resetOnEnterKey ?? true },
                        set: { viewModel.userSettings.resetOnEnterKey = $0 }
                    ))
                    .help("Reset timer when Enter key is pressed in target apps")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Floating Timer Opacity")
                        HStack {
                            Slider(
                                value: Binding(
                                    get: { viewModel.userSettings.floatingTimerOpacity ?? 1.0 },
                                    set: { viewModel.userSettings.floatingTimerOpacity = $0 }
                                ),
                                in: 0.3...1.0,
                                step: 0.1
                            ) {
                                Text("Opacity")
                            } minimumValueLabel: {
                                Text("30%")
                            } maximumValueLabel: {
                                Text("100%")
                            }
                            
                            Text("\(Int((viewModel.userSettings.floatingTimerOpacity ?? 1.0) * 100))%")
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Voice Recognition Timing") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recognition Restart Delay")
                        HStack {
                            Slider(
                                value: $viewModel.userSettings.recognitionRestartDelay,
                                in: 0.1...3.0,
                                step: 0.1
                            ) {
                                Text("Delay")
                            } minimumValueLabel: {
                                Text("0.1s")
                            } maximumValueLabel: {
                                Text("3s")
                            }
                            
                            Text(String(format: "%.1fs", viewModel.userSettings.recognitionRestartDelay))
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                        }
                    }
                    .help("Delay between voice recognition sessions")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Silence Tolerance")
                        HStack {
                            Slider(
                                value: $viewModel.userSettings.silenceTolerance,
                                in: 1.0...15.0,
                                step: 1.0
                            ) {
                                Text("Tolerance")
                            } minimumValueLabel: {
                                Text("1s")
                            } maximumValueLabel: {
                                Text("15s")
                            }
                            
                            Text(String(format: "%.1fs", viewModel.userSettings.silenceTolerance))
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                        }
                    }
                    .help("웨이크워드 감지 후 명령 입력을 기다리는 시간 (침묵 허용시간)")
                    
                    Toggle("Continuous input mode", isOn: $viewModel.userSettings.continuousInputMode)
                        .help("Enable continuous speech recognition across pauses")
                }
                
                Section("Advanced") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Log Level")
                        Picker("Log Level", selection: $viewModel.userSettings.logLevel) {
                            ForEach(LogLevel.allCases, id: \.self) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Toggle("Enable debug mode", isOn: $viewModel.userSettings.enableDebugMode)
                        .help("Shows additional debugging information in console")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Max Recording Duration")
                        HStack {
                            Slider(
                                value: $viewModel.userSettings.maxRecordingDuration,
                                in: 5...60,
                                step: 5
                            ) {
                                Text("Duration")
                            } minimumValueLabel: {
                                Text("5s")
                            } maximumValueLabel: {
                                Text("60s")
                            }
                            
                            Text("\(Int(viewModel.userSettings.maxRecordingDuration))s")
                                .frame(width: 30)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Processing Timeout")
                        HStack {
                            Slider(
                                value: $viewModel.userSettings.processingTimeout,
                                in: 5...30,
                                step: 1
                            ) {
                                Text("Timeout")
                            } minimumValueLabel: {
                                Text("5s")
                            } maximumValueLabel: {
                                Text("30s")
                            }
                            
                            Text("\(Int(viewModel.userSettings.processingTimeout))s")
                                .frame(width: 30)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            Spacer()
            
            // Action Buttons
            HStack {
                Button("Reset to Defaults") {
                    viewModel.resetToDefaults()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Button("Save") {
                    viewModel.saveSettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}