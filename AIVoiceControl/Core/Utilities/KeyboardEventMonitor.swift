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
            let activeApp = NSWorkspace.shared.frontmostApplication
            let appName = activeApp?.localizedName ?? "Unknown"
            let bundleId = activeApp?.bundleIdentifier ?? "unknown"
            print("⌨️ [KEYBOARD-MONITOR] Enter key detected - keyCode: \(event.keyCode) - App: \(appName) (\(bundleId))")
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
        
        // Remove target app restriction - Enter key reset should work from any app
        // let isTarget = isTargetAppActive()
        // #if DEBUG
        // print("⌨️ Is target app active: \(isTarget)")
        // #endif
        // guard isTarget else { return }
        
        #if DEBUG
        let activeApp = NSWorkspace.shared.frontmostApplication
        print("⏎ [KEYBOARD-MONITOR] Enter key detected in target app - delegating to StateManager")
        print("    App: \(activeApp?.localizedName ?? "Unknown") (\(activeApp?.bundleIdentifier ?? "unknown"))")
        #endif
        
        // StateManager에게 완전한 리셋 과정 위임
        // clearTextField는 false로 설정 (Enter 키 입력 시 텍스트 필드는 자체적으로 처리됨)
        NotificationCenter.default.post(
            name: .enterKeyPressed,
            object: nil,
            userInfo: [
                "reason": "enterKeyPressed",
                "clearTextField": false,  // Enter 키의 핵심 차이점
                "sourceComponent": "KeyboardEventMonitor",
                "timestamp": Date()
            ]
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