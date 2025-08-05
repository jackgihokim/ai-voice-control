//
//  SettingsWindow.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import AppKit

class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "AI Voice Control Settings"
        window.center()
        
        // Completely disable window restoration to prevent restoration warnings
        window.isRestorable = false
        window.restorationClass = nil
        window.identifier = nil
        
        // Use manual frame saving instead of setFrameAutosaveName to avoid restoration
        // window.setFrameAutosaveName("SettingsWindow") // Commented out to prevent restoration
        
        // Create hosting view with proper configuration
        let hostingView = NSHostingView(rootView: SettingsView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set content view and constraints
        window.contentView = hostingView
        
        // Ensure proper window sizing
        window.minSize = NSSize(width: 600, height: 400)
        window.maxSize = NSSize(width: 1200, height: 800)
        
        self.init(window: window)
    }
    
    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case permissions = "Permissions"
        case apps = "App Management"
        case voice = "Voice Settings"
        case about = "About"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .permissions: return "lock.shield"
            case .apps: return "app.badge"
            case .voice: return "mic"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                }
                Spacer()
            }
            .frame(width: 180)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Detail view
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab(viewModel: viewModel)
                case .permissions:
                    PermissionsTab()
                case .apps:
                    AppManagementTab(viewModel: viewModel)
                case .voice:
                    VoiceSettingsTab(viewModel: viewModel)
                case .about:
                    AboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - Preview
#Preview {
    SettingsView()
}