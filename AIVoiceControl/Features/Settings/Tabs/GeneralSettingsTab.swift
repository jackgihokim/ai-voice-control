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
                    Toggle("Auto-start listening", isOn: $viewModel.userSettings.autoStart)
                }
                
                Section("Interface") {
                    Toggle("Show menu bar icon", isOn: $viewModel.userSettings.showMenuBarIcon)
                    Toggle("Enable notifications", isOn: $viewModel.userSettings.enableNotifications)
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