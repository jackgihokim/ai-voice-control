//
//  MenuBarView.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main Content
            ScrollView {
                VStack(spacing: 16) {
                    // Status Section
                    statusSection
                    
                    // Control Section
                    controlSection
                    
                    // Transcription Section
                    if !viewModel.transcribedText.isEmpty {
                        transcriptionSection
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            footerView
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 300, height: 400)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Image(systemName: "mic.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            Text("AI Voice Control")
                .font(.headline)
            
            Spacer()
            
            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Status Section
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Status", systemImage: "info.circle")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.statusMessage)
                    .font(.body)
                
                Spacer()
                
                if viewModel.isProcessing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
        }
    }
    
    // MARK: - Control Section
    private var controlSection: some View {
        VStack(spacing: 12) {
            // Main control button
            Button(action: viewModel.toggleListening) {
                HStack {
                    Image(systemName: viewModel.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                    
                    Text(viewModel.isListening ? "Stop Listening" : "Start Listening")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.isListening ? Color.red : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing && !viewModel.isListening)
            
            // Secondary actions
            HStack(spacing: 8) {
                Button(action: viewModel.clearTranscription) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.transcribedText.isEmpty)
                
                Spacer()
                
                Button(action: { /* TODO: Open settings */ }) {
                    Label("Settings", systemImage: "gear")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    // MARK: - Transcription Section
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Last Transcription", systemImage: "text.alignleft")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView {
                Text(viewModel.transcribedText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }
            .frame(maxHeight: 100)
            
            HStack {
                Button(action: copyTranscription) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
        }
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            Text("Press ⌘K to toggle listening")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Properties
    private var statusColor: Color {
        if viewModel.isListening {
            return .red
        } else if viewModel.isProcessing {
            return .orange
        } else {
            return .green
        }
    }
    
    // MARK: - Helper Methods
    private func copyTranscription() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.transcribedText, forType: .string)
    }
}

// MARK: - Preview
#Preview {
    MenuBarView(viewModel: MenuBarViewModel())
}