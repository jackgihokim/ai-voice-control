//
//  TextFieldTestView.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI

/// Test view to compare different TextField implementations for ViewBridge error prevention
struct TextFieldTestView: View {
    @State private var safeText = ""
    @State private var minimalText = ""
    @State private var swiftuiText = ""
    @State private var nativeText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("TextField Implementation Comparison")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Test each implementation to see which prevents ViewBridge errors")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            // SafeTextField (Enhanced NSViewRepresentable)
            VStack(alignment: .leading, spacing: 8) {
                Text("1. SafeTextField (Enhanced NSViewRepresentable)")
                    .font(.headline)
                SafeTextField("Enter wake word", text: $safeText, width: 200)
                Text("Text: '\(safeText)'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // MinimalTextField (Nuclear Option)
            VStack(alignment: .leading, spacing: 8) {
                Text("2. MinimalTextField (Nuclear Option)")
                    .font(.headline)
                MinimalTextField("Enter end word", text: $minimalText, width: 200)
                Text("Text: '\(minimalText)'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // SafeSwiftUITextField (SwiftUI with global settings)
            VStack(alignment: .leading, spacing: 8) {
                Text("3. SafeSwiftUITextField (SwiftUI with global settings)")
                    .font(.headline)
                SafeSwiftUITextField("Enter app name", text: $swiftuiText, width: 200)
                Text("Text: '\(swiftuiText)'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Native SwiftUI TextField (Control)
            VStack(alignment: .leading, spacing: 8) {
                Text("4. Native SwiftUI TextField (Control)")
                    .font(.headline)
                TextField("Enter bundle ID", text: $nativeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Text("Text: '\(nativeText)'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Testing Instructions:")
                    .font(.headline)
                
                Text("1. Open Console.app and filter for 'ViewBridge'")
                Text("2. Click on each text field above")
                Text("3. Type some text in each field")
                Text("4. Observe which implementations trigger ViewBridge errors")
                Text("5. The best implementation should produce no ViewBridge errors")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Preview
#Preview {
    TextFieldTestView()
        .frame(width: 500, height: 600)
}