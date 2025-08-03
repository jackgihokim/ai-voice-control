//
//  AppManagementTab.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import AppKit
import AVFoundation

struct AppManagementTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingAddApp = false
    @State private var selectedApp: AppConfiguration?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("App Management")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Manage applications that can be controlled with voice commands")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Default Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default Execution Words")
                        .font(.headline)
                    
                    Text("These execution words will be used for all new apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Default execution words list with add/remove functionality
                    DefaultExecutionWordsView(executionWords: $viewModel.userSettings.defaultExecutionWords)
                }
                
                Divider()
                
                // Registered Apps
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Registered Apps")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { showingAddApp = true }) {
                            Label("Add App", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if viewModel.userSettings.registeredApps.isEmpty {
                        // Empty State
                        VStack(spacing: 16) {
                            Image(systemName: "app.badge")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No apps registered yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Add apps to control them with voice commands")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Add Your First App") {
                                showingAddApp = true
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, minHeight: 150)
                    } else {
                        // Apps List
                        VStack(spacing: 8) {
                            ForEach(Array(viewModel.userSettings.registeredApps.enumerated()), id: \.element.id) { index, app in
                                AppRow(
                                    app: app,
                                    onToggle: {
                                        var updatedApp = app
                                        updatedApp.toggle()
                                        viewModel.updateApp(updatedApp, at: index)
                                    },
                                    onEdit: {
                                        selectedApp = app
                                    },
                                    onDelete: {
                                        viewModel.removeApp(at: index)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddApp) {
            AddAppSheet(
                defaultExecutionWords: viewModel.userSettings.defaultExecutionWords,
                onAddApp: { app in
                    viewModel.addApp(app)
                    showingAddApp = false
                },
                onCancel: {
                    showingAddApp = false
                }
            )
        }
        .sheet(item: $selectedApp) { app in
            EditAppSheet(
                app: app,
                onSave: { updatedApp in
                    if let index = viewModel.userSettings.registeredApps.firstIndex(where: { $0.id == app.id }) {
                        viewModel.updateApp(updatedApp, at: index)
                    }
                    selectedApp = nil
                },
                onCancel: {
                    selectedApp = nil
                }
            )
        }
    }
}

// MARK: - App Row Component

struct AppRow: View {
    let app: AppConfiguration
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            Group {
                if let icon = app.iconImage {
                    Image(nsImage: icon)
                        .resizable()
                } else {
                    Image(systemName: "app")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 32, height: 32)
            
            // App Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(app.name)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if app.hasCustomVoiceSettings {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .help("Custom voice settings")
                    }
                    
                    if !app.isInstalled {
                        Text("Not Installed")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                }
                
                Text("Wake words: \(app.wakeWords.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 8) {
                Toggle("", isOn: .init(
                    get: { app.isEnabled },
                    set: { _ in onToggle() }
                ))
                
                Button(action: onEdit) {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit app settings and voice configuration")
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .opacity(app.isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Add App Sheet

struct AddAppSheet: View {
    let defaultExecutionWords: [String]
    let onAddApp: (AppConfiguration) -> Void
    let onCancel: () -> Void
    
    @State private var installedApps: [AppInfo] = []
    @State private var searchText = ""
    @State private var selectedApp: AppInfo?
    @State private var isLoadingApps = true
    @State private var showConfigureStep = false
    @State private var wakeWords: [String] = []
    @State private var newWakeWord = ""
    
    struct AppInfo {
        let name: String
        let bundleIdentifier: String
        let icon: NSImage?
        let url: URL
    }
    
    var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText) ||
            app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if !showConfigureStep {
                // Step 1: Select App
                VStack(spacing: 20) {
                    // Header
                    Text("Select Application")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        UltraSimpleTextField("Search apps...", text: $searchText)
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Apps list
                    if isLoadingApps {
                        ProgressView("Loading installed applications...")
                            .frame(height: 300)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(filteredApps, id: \.bundleIdentifier) { app in
                                    HStack(spacing: 12) {
                                        if let icon = app.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 32, height: 32)
                                        } else {
                                            Image(systemName: "app")
                                                .frame(width: 32, height: 32)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text(app.name)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            
                                            Text(app.bundleIdentifier)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedApp?.bundleIdentifier == app.bundleIdentifier ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        selectedApp = app
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(height: 300)
                    }
                    
                    // Buttons
                    HStack {
                        Button("Cancel", action: onCancel)
                            .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Next") {
                            if let app = selectedApp {
                                wakeWords = [app.name]  // Initialize with app name
                                showConfigureStep = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedApp == nil)
                    }
                }
            } else {
                // Step 2: Configure Wake Words
                VStack(spacing: 20) {
                    // Header with app info
                    HStack(spacing: 12) {
                        if let app = selectedApp, let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 48, height: 48)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Configure Wake Words")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let app = selectedApp {
                                Text(app.name)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Wake words configuration
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Wake Words")
                            .font(.headline)
                        
                        Text("Say any of these words to activate this app")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Wake word list - horizontal layout
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(wakeWords.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Text(wakeWords[index])
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(4)
                                    
                                    Button(action: {
                                        wakeWords.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(wakeWords.count <= 1)
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                        
                        // Add new wake word
                        HStack {
                            UltraSimpleTextField("Add wake word", text: $newWakeWord) {
                                addWakeWord()
                            }
                            
                            Button("Add") {
                                addWakeWord()
                            }
                            .buttonStyle(.bordered)
                            .disabled(newWakeWord.isEmpty)
                        }
                    }
                    
                    Spacer()
                    
                    // Buttons
                    HStack {
                        Button("Back") {
                            showConfigureStep = false
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Add") {
                            if let app = selectedApp {
                                let config = AppConfiguration(
                                    name: app.name,
                                    bundleIdentifier: app.bundleIdentifier,
                                    wakeWords: wakeWords,
                                    executionWords: defaultExecutionWords,
                                    iconImage: app.icon
                                )
                                onAddApp(config)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding()
        .frame(width: 500, height: 500)
        .onAppear {
            loadInstalledApps()
        }
    }
    
    private func addWakeWord() {
        if !newWakeWord.isEmpty && !wakeWords.contains(newWakeWord) {
            wakeWords.append(newWakeWord)
            newWakeWord = ""
        }
    }
    
    private func loadInstalledApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            var apps: [AppInfo] = []
            var loadErrors: [String] = []
            
            // Get all applications from /Applications and ~/Applications
            let appDirectories = [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: NSHomeDirectory() + "/Applications"),
                URL(fileURLWithPath: "/System/Applications")
            ]
            
            let fileManager = FileManager.default
            
            for directory in appDirectories {
                do {
                    let appURLs = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                    
                    for appURL in appURLs where appURL.pathExtension == "app" {
                        if let bundle = Bundle(url: appURL),
                           let bundleID = bundle.bundleIdentifier,
                           let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                            
                            // Get app icon safely
                            var appIcon: NSImage?
                            if let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconName") as? String {
                                appIcon = NSImage(named: iconName)
                            }
                            if appIcon == nil {
                                appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
                            }
                            
                            let appInfo = AppInfo(
                                name: appName,
                                bundleIdentifier: bundleID,
                                icon: appIcon,
                                url: appURL
                            )
                            apps.append(appInfo)
                        }
                    }
                } catch {
                    // Log directory access errors but continue
                    loadErrors.append("Failed to access directory \(directory.path): \(error.localizedDescription)")
                }
            }
            
            // Sort apps alphabetically by name
            apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            DispatchQueue.main.async {
                self.installedApps = apps
                self.isLoadingApps = false
                
                // Log any errors that occurred during loading
                if !loadErrors.isEmpty {
                    print("App loading errors:")
                    loadErrors.forEach { print("  - \($0)") }
                }
            }
        }
    }
}

// MARK: - Edit App Sheet

struct EditAppSheet: View {
    let app: AppConfiguration
    let onSave: (AppConfiguration) -> Void
    let onCancel: () -> Void
    
    @State private var editedApp: AppConfiguration
    @State private var newWakeWord = ""
    @State private var newExecutionWord = ""
    @State private var useCustomVoiceSettings = false
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var isTestingVoice = false
    @State private var speechSynthesizer: AVSpeechSynthesizer?
    
    init(app: AppConfiguration, onSave: @escaping (AppConfiguration) -> Void, onCancel: @escaping () -> Void) {
        self.app = app
        self.onSave = onSave
        self.onCancel = onCancel
        self._editedApp = State(initialValue: app)
        self._useCustomVoiceSettings = State(initialValue: app.hasCustomVoiceSettings)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit \(app.name)")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                Section("Wake Words") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Wake word list - horizontal layout
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(editedApp.wakeWords.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Text(editedApp.wakeWords[index])
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(4)
                                    
                                    Button(action: {
                                        editedApp.wakeWords.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(editedApp.wakeWords.count <= 1) // At least one wake word required
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                        
                        // Add new wake word
                        HStack {
                            UltraSimpleTextField("Add wake word", text: $newWakeWord) {
                                addWakeWordToEditedApp()
                            }
                            
                            Button("Add") {
                                addWakeWordToEditedApp()
                            }
                            .buttonStyle(.bordered)
                            .disabled(newWakeWord.isEmpty)
                        }
                    }
                    
                    // Execution words section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Execution Words")
                        
                        // Execution word list - horizontal layout
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(editedApp.executionWords.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Text(editedApp.executionWords[index])
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .cornerRadius(4)
                                    
                                    Button(action: {
                                        editedApp.executionWords.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(editedApp.executionWords.count <= 1) // At least one execution word required
                                    .offset(x: 4, y: -4)
                                }
                            }
                        }
                        
                        // Add new execution word
                        HStack {
                            UltraSimpleTextField("Add execution word", text: $newExecutionWord) {
                                addExecutionWordToEditedApp()
                            }
                            
                            Button("Add") {
                                addExecutionWordToEditedApp()
                            }
                            .buttonStyle(.bordered)
                            .disabled(newExecutionWord.isEmpty)
                        }
                    }
                }
                
                Section("Behavior") {
                    Toggle("Auto-submit on execution word", isOn: $editedApp.autoSubmit)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt Template")
                        UltraSimpleTextField("Template", text: $editedApp.promptTemplate)
                        Text("Use {input} to insert voice input")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Voice Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Use custom voice settings", isOn: $useCustomVoiceSettings)
                            .onChange(of: useCustomVoiceSettings) { _, newValue in
                                if !newValue {
                                    // Clear custom settings when toggled off
                                    editedApp.selectedVoiceId = nil
                                    editedApp.speechRate = nil
                                    editedApp.voiceOutputVolume = nil
                                } else {
                                    // Set default values when toggled on
                                    editedApp.speechRate = 0.5
                                    editedApp.voiceOutputVolume = 0.8
                                }
                            }
                        
                        Text("Toggle to enable custom voice settings for this app. When disabled, global voice settings will be used.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if useCustomVoiceSettings {
                        VStack(alignment: .leading, spacing: 12) {
                            // Voice selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Voice")
                                if availableVoices.isEmpty {
                                    HStack {
                                        Text("System Default Voice")
                                            .foregroundColor(.secondary)
                                        
                                        Button("Load Voices") {
                                            loadAllSystemVoices()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                } else {
                                    Picker("Voice", selection: Binding(
                                        get: { editedApp.selectedVoiceId ?? "" },
                                        set: { editedApp.selectedVoiceId = $0.isEmpty ? nil : $0 }
                                    )) {
                                        Text("System Default").tag("")
                                        
                                        ForEach(availableVoices, id: \.identifier) { voice in
                                            Text("\(voice.name) (\(voice.language))")
                                                .tag(voice.identifier)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                            
                            // Speech rate
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Speech Rate")
                                HStack {
                                    Slider(
                                        value: Binding(
                                            get: { editedApp.speechRate ?? 0.5 },
                                            set: { editedApp.speechRate = $0 }
                                        ),
                                        in: 0.1...1.0,
                                        step: 0.1
                                    )
                                    
                                    Text("\(Int((editedApp.speechRate ?? 0.5) * 100))%")
                                        .frame(width: 40)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Volume
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Volume")
                                HStack {
                                    Slider(
                                        value: Binding(
                                            get: { editedApp.voiceOutputVolume ?? 0.8 },
                                            set: { editedApp.voiceOutputVolume = $0 }
                                        ),
                                        in: 0.0...1.0,
                                        step: 0.1
                                    )
                                    
                                    Text("\(Int((editedApp.voiceOutputVolume ?? 0.8) * 100))%")
                                        .frame(width: 40)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Test voice button
                            Button("Test Voice") {
                                testAppVoice()
                            }
                            .buttonStyle(.bordered)
                            .disabled(isTestingVoice)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    onSave(editedApp)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500, height: 700)
        .onDisappear {
            // Clean up speech synthesizer when view disappears
            speechSynthesizer?.stopSpeaking(at: .immediate)
            speechSynthesizer = nil
        }
    }
    
    private func addWakeWordToEditedApp() {
        if !newWakeWord.isEmpty && !editedApp.wakeWords.contains(newWakeWord) {
            editedApp.wakeWords.append(newWakeWord)
            newWakeWord = ""
        }
    }
    
    private func addExecutionWordToEditedApp() {
        if !newExecutionWord.isEmpty && !editedApp.executionWords.contains(newExecutionWord) {
            editedApp.executionWords.append(newExecutionWord)
            newExecutionWord = ""
        }
    }
    
    private func loadAllSystemVoices() {
        // Load voices on background queue to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async {
            // Small delay to prevent UI blocking
            Thread.sleep(forTimeInterval: 0.5)
            
            let voices = AVSpeechSynthesisVoice.speechVoices()
            let sortedVoices = voices.sorted { $0.name < $1.name }
            
            DispatchQueue.main.async {
                self.availableVoices = sortedVoices
            }
        }
    }
    
    private func testAppVoice() {
        isTestingVoice = true
        
        // Stop any existing speech
        speechSynthesizer?.stopSpeaking(at: .immediate)
        
        // Create new synthesizer if needed
        if speechSynthesizer == nil {
            speechSynthesizer = AVSpeechSynthesizer()
        }
        
        let message = "This is a test of the voice settings for \(editedApp.name)"
        let utterance = AVSpeechUtterance(string: message)
        
        // Apply app-specific settings
        utterance.rate = Float((editedApp.speechRate ?? 0.5) * 0.5)
        utterance.volume = Float(editedApp.voiceOutputVolume ?? 0.8)
        
        if let voiceId = editedApp.selectedVoiceId,
           !voiceId.isEmpty,
           let voice = availableVoices.first(where: { $0.identifier == voiceId }) {
            utterance.voice = voice
        }
        
        // Speak the utterance
        speechSynthesizer?.speak(utterance)
        
        // Use a timer to reset the testing state after speech completes
        Task {
            do {
                // Estimate duration based on message length and speech rate
                let estimatedDuration = Double(message.count) * 0.06 / Double(utterance.rate)
                try await Task.sleep(for: .seconds(max(3.0, estimatedDuration)))
                
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
}

// MARK: - Default Execution Words View

struct DefaultExecutionWordsView: View {
    @Binding var executionWords: [String]
    @State private var newExecutionWord = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Execution word list - horizontal layout
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(executionWords.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Text(executionWords[index])
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                        
                        Button(action: {
                            executionWords.remove(at: index)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(executionWords.count <= 1) // At least one execution word required
                        .offset(x: 4, y: -4)
                    }
                }
            }
            
            // Add new execution word
            HStack {
                UltraSimpleTextField("Add execution word", text: $newExecutionWord, width: 150) {
                    addExecutionWord()
                }
                
                Button("Add") {
                    addExecutionWord()
                }
                .buttonStyle(.bordered)
                .disabled(newExecutionWord.isEmpty)
            }
        }
    }
    
    private func addExecutionWord() {
        if !newExecutionWord.isEmpty && !executionWords.contains(newExecutionWord) {
            executionWords.append(newExecutionWord)
            newExecutionWord = ""
        }
    }
}