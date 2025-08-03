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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // DEBUG: Reset UserDefaults if needed (comment out in production)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-reset-defaults") {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            UserDefaults.standard.synchronize()
            print("🗑️ UserDefaults reset for debugging")
        }
        #endif
        
        // ULTRA NUCLEAR OPTION: Kill ALL ViewBridge connections
        SimpleViewBridgeKiller.activateNuclearOption()
        
        // Completely disable window restoration system
        NSApplication.shared.disableRelaunchOnLogin()
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        
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
        // Clear any restoration data on app termination
        UserDefaults.standard.removeObject(forKey: "NSQuitAlwaysKeepsWindows")
        UserDefaults.standard.synchronize()
    }
}