//
//  FloatingTimerWindow.swift
//  AIVoiceControl
//
//  Created by Claude on 2025-08-16.
//

import AppKit
import SwiftUI

class FloatingTimerWindow: NSWindow {
    private var timerView: FloatingTimerView!
    private let stateManager = VoiceControlStateManager.shared
    
    init() {
        let settings = UserSettings.load()
        let savedPosition = settings.floatingTimerPosition ?? CGPoint(x: 100, y: 100)
        let contentRect = NSRect(origin: savedPosition, size: NSSize(width: 200, height: 50))
        
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupView()
        
        #if DEBUG
        print("🪟 FloatingTimerWindow created at position: \(savedPosition)")
        #endif
    }
    
    private func setupWindow() {
        // Always on top
        level = .floating
        
        // Transparent background
        isOpaque = false
        backgroundColor = NSColor.clear
        
        // Show on all spaces
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        // Allow interaction but don't steal focus
        ignoresMouseEvents = false
        
        // Don't show in window list
        isExcludedFromWindowsMenu = true
        
        // Prevent window restoration
        isRestorable = false
        restorationClass = nil
        
        #if DEBUG
        print("🪟 Floating window configured")
        #endif
    }
    
    private func setupView() {
        timerView = FloatingTimerView { [weak self] newPosition in
            self?.savePosition(newPosition)
        }
        
        let hostingView = NSHostingView(rootView: timerView)
        contentView = hostingView
        
        // Apply opacity from settings
        let settings = UserSettings.load()
        alphaValue = settings.floatingTimerOpacity ?? 1.0
        
        #if DEBUG
        print("🎨 Floating timer view setup complete")
        #endif
    }
    
    private func savePosition(_ position: CGPoint) {
        var settings = UserSettings.load()
        settings.floatingTimerPosition = position
        settings.save()
        
        #if DEBUG
        print("💾 Saved floating timer position: \(position)")
        #endif
    }
    
    override func mouseDown(with event: NSEvent) {
        // Allow dragging the window
        super.mouseDown(with: event)
        
        // Save position after drag
        let newPosition = frame.origin
        savePosition(newPosition)
    }
    
    func showIfNeeded() {
        let settings = UserSettings.load()
        if settings.showFloatingTimer == true && stateManager.isListening {
            orderFront(nil)
            #if DEBUG
            print("👁️ Floating timer shown")
            #endif
        }
    }
    
    func hideIfNeeded() {
        if !stateManager.isListening {
            orderOut(nil)
            #if DEBUG
            print("🙈 Floating timer hidden")
            #endif
        }
    }
    
    func updateOpacity() {
        let settings = UserSettings.load()
        alphaValue = settings.floatingTimerOpacity ?? 1.0
    }
}