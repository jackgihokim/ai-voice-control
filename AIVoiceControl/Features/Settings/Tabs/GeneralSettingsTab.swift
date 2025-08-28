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
                
                Section("Voice Recognition") {
                    Toggle("Continuous input mode", isOn: $viewModel.userSettings.continuousInputMode)
                        .help("Enable continuous speech recognition across pauses")
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("자동 구두점 추가", isOn: $viewModel.userSettings.autoAddPunctuation)
                            .help("음성 인식 결과에 자동으로 마침표, 물음표 등을 추가합니다")
                        
                        if viewModel.userSettings.autoAddPunctuation {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("구두점 추가 스타일")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("", selection: $viewModel.userSettings.punctuationStyle) {
                                    ForEach(PunctuationStyle.allCases, id: \.self) { style in
                                        VStack(alignment: .leading) {
                                            Text(style.displayName)
                                                .font(.body)
                                            Text(style.description)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .tag(style)
                                    }
                                }
                                .pickerStyle(RadioGroupPickerStyle())
                                .padding(.leading, 20)
                                
                                // 예시 표시
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("예시:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    let examples = [
                                        ("오늘 날씨 어때요", "오늘 날씨 어때요?"),
                                        ("회의 일정 확인해줘", "회의 일정 확인해줘."),
                                        ("정말 좋네요", "정말 좋네요!")
                                    ]
                                    
                                    ForEach(examples, id: \.0) { input, output in
                                        HStack(spacing: 8) {
                                            Text(input)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("→")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(output)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                        }
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.leading, 20)
                            }
                        }
                    }
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