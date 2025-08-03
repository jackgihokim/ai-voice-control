//
//  SettingsViewModel.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var userSettings: UserSettings
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load user settings from UserDefaults
        self.userSettings = UserSettings.load()
        
        // Setup bindings to save changes automatically
        setupAutoSave()
    }
    
    // MARK: - Public Methods
    
    func saveSettings() {
        userSettings.save()
    }
    
    func resetToDefaults() {
        userSettings = UserSettings()
        saveSettings()
    }
    
    func addApp(_ app: AppConfiguration) {
        userSettings.registeredApps.append(app)
        saveSettings()
    }
    
    func removeApp(at index: Int) {
        guard index < userSettings.registeredApps.count else { return }
        userSettings.registeredApps.remove(at: index)
        saveSettings()
    }
    
    func updateApp(_ app: AppConfiguration, at index: Int) {
        guard index < userSettings.registeredApps.count else { return }
        userSettings.registeredApps[index] = app
        saveSettings()
    }
    
    // MARK: - Private Methods
    
    private func setupAutoSave() {
        // Auto-save when settings change
        $userSettings
            .dropFirst() // Skip initial value
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }
}