//
//  KeyboardEventMonitor.swift
//  AIVoiceControl
//
//  Created by Claude on 2025-08-16.
//

import AppKit
import Foundation

class KeyboardEventMonitor {
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    
    init() {
        #if DEBUG
        print("⌨️ KeyboardEventMonitor initialized")
        #endif
    }
    
    func startMonitoring() {
        stopMonitoring() // Ensure we don't have duplicate monitors
        
        // Monitor local events (when our app is active)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
        
        // Monitor global events (when other apps are active)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        #if DEBUG
        print("⌨️ Started keyboard monitoring (local and global)")
        #endif
    }
    
    func stopMonitoring() {
        if let localMonitor = localEventMonitor {
            NSEvent.removeMonitor(localMonitor)
            localEventMonitor = nil
        }
        
        if let globalMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalMonitor)
            globalEventMonitor = nil
        }
        
        #if DEBUG
        print("⌨️ Stopped keyboard monitoring")
        #endif
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        #if DEBUG
        // Log all key events to debug
        if event.keyCode == 36 || event.keyCode == 76 {
            print("⌨️ Enter key detected - keyCode: \(event.keyCode)")
        }
        #endif
        
        // Check if it's the Enter key (keyCode 36 or 76)
        guard event.keyCode == 36 || event.keyCode == 76 else { return }
        
        #if DEBUG
        print("⌨️ Enter key confirmed")
        #endif
        
        // Check if settings allow Enter key reset
        let settings = UserSettings.load()
        #if DEBUG
        print("⌨️ resetOnEnterKey setting: \(settings.resetOnEnterKey ?? false)")
        #endif
        guard settings.resetOnEnterKey == true else { 
            #if DEBUG
            print("⌨️ Enter key reset disabled in settings")
            #endif
            return 
        }
        
        // Check if the active app is one of our target apps
        let isTarget = isTargetAppActive()
        #if DEBUG
        print("⌨️ Is target app active: \(isTarget)")
        #endif
        guard isTarget else { return }
        
        #if DEBUG
        print("⏎ Enter key detected in target app - posting timer reset notification")
        #endif
        
        // Post notification to reset timer
        NotificationCenter.default.post(
            name: .enterKeyPressed,
            object: nil,
            userInfo: ["timestamp": Date()]
        )
    }
    
    private func isTargetAppActive() -> Bool {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            #if DEBUG
            print("❌ No frontmost application found")
            #endif
            return false
        }
        
        #if DEBUG
        print("🔍 Active app: \(activeApp.localizedName ?? "Unknown") (\(activeApp.bundleIdentifier ?? "Unknown bundle ID"))")
        #endif
        
        let settings = UserSettings.load()
        let targetApps = settings.registeredApps
        
        #if DEBUG
        print("🎯 Registered target apps:")
        for app in targetApps {
            print("   - \(app.name): \(app.bundleIdentifier)")
        }
        #endif
        
        let isTarget = targetApps.contains { config in
            config.bundleIdentifier == activeApp.bundleIdentifier
        }
        
        #if DEBUG
        if isTarget {
            print("✅ Active app \(activeApp.localizedName ?? "Unknown") is a target app")
        } else {
            print("❌ Active app \(activeApp.localizedName ?? "Unknown") is NOT a target app")
        }
        #endif
        
        return isTarget
    }
    
    deinit {
        stopMonitoring()
        #if DEBUG
        print("⌨️ KeyboardEventMonitor deinitialized")
        #endif
    }
}