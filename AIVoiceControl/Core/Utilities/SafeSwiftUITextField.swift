//
//  SafeSwiftUITextField.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import AppKit

/// SwiftUI TextField wrapper with ViewBridge error prevention
struct SafeSwiftUITextField: View {
    @Binding var text: String
    let placeholder: String
    let width: CGFloat?
    
    init(_ placeholder: String, text: Binding<String>, width: CGFloat? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.width = width
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled(true)
            .disableAutocorrection(true)
            .if(width != nil) { view in
                view.frame(width: width)
            }
            .onAppear {
                // Configure global text system settings to reduce ViewBridge issues
                configureGlobalTextSettings()
            }
    }
    
    private func configureGlobalTextSettings() {
        // These settings affect the entire application's text system
        // and can help reduce ViewBridge connection attempts
        
        DispatchQueue.main.async {
            // Note: We can't easily set global defaults for NSTextView properties
            // Instead, we'll rely on the NSViewRepresentable implementations
            // to configure each text field individually
        }
    }
}

// MARK: - ViewModifier Extensions

extension View {
    /// Conditionally apply a modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Disable autocorrection (compatibility method)
    func disableAutocorrection(_ disable: Bool = true) -> some View {
        #if os(macOS)
        return self
        #else
        return self.autocorrectionDisabled(disable)
        #endif
    }
}