//
//  AIVoiceControlApp.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/30/25.
//

import SwiftUI
import AppKit

@main
struct AIVoiceControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
