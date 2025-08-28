//
//  FloatingTimerView.swift
//  AIVoiceControl
//
//  Created by Claude on 2025-08-16.
//

import SwiftUI

struct FloatingTimerView: View {
    @ObservedObject private var stateManager = VoiceControlStateManager.shared
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero
    
    let onPositionChanged: (CGPoint) -> Void
    
    init(onPositionChanged: @escaping (CGPoint) -> Void) {
        self.onPositionChanged = onPositionChanged
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)
                .opacity(isDragging ? 1.0 : 0.6)
            
            // Progress bar
            ProgressView(value: Double(stateManager.remainingTime), total: 59)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 80)
                .tint(progressColor)
            
            // Time display
            Text("\(stateManager.remainingTime)s")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(timeColor)
                .frame(width: 30)
            
            // Play/Pause button
            Button(action: toggleListening) {
                Image(systemName: stateManager.isListening ? "pause.circle.fill" : "play.circle.fill")
                    .foregroundColor(.primary)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Refresh button
            Button(action: refreshListening) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundColor(.primary)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!stateManager.isListening)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                    }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    dragOffset = .zero
                    
                    // Calculate new window position
                    if let window = NSApp.windows.first(where: { $0 is FloatingTimerWindow }) {
                        let newOrigin = CGPoint(
                            x: window.frame.origin.x + value.translation.width,
                            y: window.frame.origin.y - value.translation.height // Flip Y coordinate
                        )
                        window.setFrameOrigin(newOrigin)
                        onPositionChanged(newOrigin)
                    }
                }
        )
        .onHover { hovering in
            if hovering && !isDragging {
                NSCursor.openHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
    
    private var progressColor: Color {
        if stateManager.remainingTime <= 10 {
            return .red
        } else if stateManager.remainingTime <= 30 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var timeColor: Color {
        stateManager.remainingTime <= 10 ? .red : .primary
    }
    
    private var borderColor: Color {
        if stateManager.remainingTime <= 10 {
            return .red.opacity(0.5)
        }
        return Color(NSColor.separatorColor)
    }
    
    private func toggleListening() {
        Task {
            do {
                try await stateManager.toggleListening()
            } catch {
                #if DEBUG
                print("❌ Failed to toggle listening from floating timer: \(error)")
                #endif
            }
        }
    }
    
    private func refreshListening() {
        Task {
            await stateManager.refreshListening()
        }
    }
}

#Preview {
    FloatingTimerView { _ in }
        .frame(width: 200, height: 50)
}