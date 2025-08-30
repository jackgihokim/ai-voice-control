//
//  AppDelegate.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var menuBarViewModel: MenuBarViewModel?
    private var settingsWindowController: SettingsWindowController?
    private let stateManager = VoiceControlStateManager.shared
    private var floatingTimerWindow: FloatingTimerWindow?
    private var keyboardMonitor = KeyboardEventMonitor()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // DEBUG: Reset UserDefaults if needed (comment out in production)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-reset-defaults") {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            UserDefaults.standard.synchronize()
        }
        #endif
        
        // SAFE: Minimize ViewBridge connections
        SimpleViewBridgeKiller.activateNuclearOption()
        
        // Disable window restoration system
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        
        // Initialize permission manager and check permissions
        Task { @MainActor in
            PermissionManager.shared.updateAllPermissionStatuses()
        }
        
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set up the status bar button
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.circle", accessibilityDescription: "AI Voice Control")
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create the view model
        menuBarViewModel = MenuBarViewModel()
        
        // Set voice engine reference in state manager
        if let voiceEngine = menuBarViewModel?.voiceRecognitionEngine {
            stateManager.setVoiceEngine(voiceEngine)
        }
        
        // Create the popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView(viewModel: menuBarViewModel!))
        
        // Disable restoration for popover as well
        if let popoverWindow = popover?.contentViewController?.view.window {
            popoverWindow.isRestorable = false
            popoverWindow.restorationClass = nil
        }
        
        // Setup notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showPreferences),
            name: .openSettings,
            object: nil
        )
        
        // Add app lifecycle observers for permission monitoring
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )
        
        // Monitor active application changes to maintain voice recognition
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationDidChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Setup floating timer window
        setupFloatingTimer()
        
        // Start keyboard monitoring for Enter key reset
        keyboardMonitor.startMonitoring()
        
        // Auto-start voice recognition if enabled
        Task { @MainActor in
            let settings = UserSettings.load()
            if settings.autoStartListening == true {
                #if DEBUG
                print("🚀 Auto-starting voice recognition...")
                #endif
                
                // Wait a moment for all components to be fully initialized
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                do {
                    try await stateManager.startListening()
                    #if DEBUG
                    print("✅ Auto-start completed successfully")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Auto-start failed: \(error)")
                    #endif
                }
            } else {
                #if DEBUG
                print("⏸️ Auto-start disabled in settings")
                #endif
            }
        }
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                // Show context menu on right-click
                showContextMenu()
            } else {
                // Toggle popover on left-click
                if let popover = popover {
                    if popover.isShown {
                        popover.performClose(nil)
                    } else {
                        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                    }
                }
            }
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let aboutItem = NSMenuItem(title: "About AI Voice Control", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        #if DEBUG
        menu.addItem(NSMenuItem.separator())
        
        let resetItem = NSMenuItem(title: "Reset All Settings (Debug)", action: #selector(resetSettings), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        #endif
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "AI Voice Control"
        alert.informativeText = "Version 1.0\n\nAn AI-powered voice control system for macOS.\n\n© 2025"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func showPreferences() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow()
    }
    
    @MainActor @objc private func applicationDidBecomeActive() {
        #if DEBUG
        print("🔄 App became active - resuming permission monitoring")
        #endif
        
        // Resume permission monitoring when app becomes active
        PermissionManager.shared.resumePermissionMonitoring()
        
        // Force immediate permission check
        PermissionManager.shared.updateAllPermissionStatuses()
    }
    
    @MainActor @objc private func applicationWillResignActive() {
        #if DEBUG
        print("⏸️ App will resign active - stopping permission monitoring")
        #endif
        
        // Stop permission monitoring when app goes to background
        PermissionManager.shared.stopPermissionMonitoring()
    }
    
    @MainActor @objc private func activeApplicationDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let appName = app.localizedName ?? "Unknown"
        let bundleId = app.bundleIdentifier ?? "unknown"
        
        #if DEBUG
        print("📱 [APP-SWITCH] Active app changed to: \(appName) (\(bundleId))")
        #endif
        
        // Check if voice recognition should continue running
        let stateManager = VoiceControlStateManager.shared
        
        // If voice recognition was running but got stopped during app switch, restart it
        if stateManager.autoStartEnabled && !stateManager.isListening && !stateManager.isTransitioning {
            #if DEBUG
            print("🔄 [APP-SWITCH] Voice recognition stopped during app switch - restarting...")
            #endif
            
            Task {
                try? await Task.sleep(nanoseconds: 200_000_000) // Wait 0.2s for app switch to complete
                
                do {
                    try await stateManager.startListening()
                    #if DEBUG
                    print("✅ [APP-SWITCH] Voice recognition restarted successfully")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ [APP-SWITCH] Failed to restart voice recognition: \(error)")
                    #endif
                }
            }
        }
    }
    
    #if DEBUG
    @objc private func resetSettings() {
        let alert = NSAlert()
        alert.messageText = "Reset All Settings?"
        alert.informativeText = "This will delete all app settings and preferences. The app will quit and you'll need to restart it."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Close settings window if open
            settingsWindowController?.window?.close()
            
            // Delete all UserDefaults
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            UserDefaults.standard.synchronize()
            
            // Quit the app
            NSApplication.shared.terminate(nil)
        }
    }
    #endif
    
    // MARK: - Window Restoration Prevention
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
    
    func application(_ application: NSApplication, willEncodeRestorableState coder: NSCoder) {
        // Explicitly prevent encoding any restorable state
    }
    
    func application(_ application: NSApplication, didDecodeRestorableState coder: NSCoder) {
        // Explicitly prevent decoding any restorable state
    }
    
    func application(_ sender: NSApplication, delegateHandlesKey key: String) -> Bool {
        // Prevent handling of restoration-related keys
        if key.contains("NSWindow") || key.contains("restoration") {
            return false
        }
        return false
    }
    
    // Override window restoration methods
    func application(_ application: NSApplication, restoreWindowWithIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
        // Always return nil to prevent any window restoration
        completionHandler(nil, nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Stop keyboard monitoring
        keyboardMonitor.stopMonitoring()
        
        // Clear any restoration data on app termination
        UserDefaults.standard.removeObject(forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Floating Timer Setup
    
    private func setupFloatingTimer() {
        let settings = UserSettings.load()
        
        if settings.showFloatingTimer == true {
            floatingTimerWindow = FloatingTimerWindow()
            
            // Setup state manager observation to show/hide timer
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleVoiceControlStateChanged(_:)),
                name: .voiceControlStateChanged,
                object: nil
            )
            
            #if DEBUG
            print("🪟 Floating timer setup completed")
            #endif
        } else {
            #if DEBUG
            print("🪟 Floating timer disabled in settings")
            #endif
        }
    }
    
    @objc private func handleVoiceControlStateChanged(_ notification: Notification) {
        guard let isListening = notification.userInfo?["isListening"] as? Bool else { return }
        
        DispatchQueue.main.async { [weak self] in
            if isListening {
                self?.floatingTimerWindow?.showIfNeeded()
            } else {
                self?.floatingTimerWindow?.hideIfNeeded()
            }
        }
    }
}