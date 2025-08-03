//
//  MinimalTextField.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import AppKit

/// Ultra-minimal TextField implementation to completely avoid ViewBridge connections
struct MinimalTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let width: CGFloat?
    
    init(_ placeholder: String, text: Binding<String>, width: CGFloat? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.width = width
    }
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = MinimalNSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.stringValue = text
        
        // Minimal styling to avoid complex ViewBridge connections
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .none  // This is crucial - prevents focus ring ViewBridge
        
        // Completely disable all advanced text features
        textField.allowsEditingTextAttributes = false
        textField.importsGraphics = false
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        
        if let width = width {
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: MinimalTextField
        
        init(_ parent: MinimalTextField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            DispatchQueue.main.async {
                self.parent.text = textField.stringValue
            }
        }
    }
}

/// Minimal NSTextField that overrides methods to prevent ViewBridge connections
class MinimalNSTextField: NSTextField {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupMinimalTextField()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupMinimalTextField()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMinimalTextField()
    }
    
    private func setupMinimalTextField() {
        // Disable focus ring completely - this prevents many ViewBridge connections
        focusRingType = .none
        
        // Disable all editing attributes to prevent ViewBridge text service connections
        allowsEditingTextAttributes = false
        importsGraphics = false
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        
        // Immediately configure field editor when becoming first responder
        if let editor = currentEditor() as? NSTextView {
            configureMinimalFieldEditor(editor)
        }
        
        return result
    }
    
    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        
        // Configure field editor when editing begins
        if let editor = currentEditor() as? NSTextView {
            configureMinimalFieldEditor(editor)
        }
    }
    
    private func configureMinimalFieldEditor(_ editor: NSTextView) {
        // This is the key method - aggressively disable ALL automatic features
        // that could trigger ViewBridge connections
        
        editor.isAutomaticTextCompletionEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.isAutomaticDataDetectionEnabled = false
        editor.isGrammarCheckingEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        
        // Nuclear option: Clear and invalidate input context
        if let inputContext = editor.inputContext {
            inputContext.discardMarkedText()
            inputContext.invalidateCharacterCoordinates()
            
            // Try to prevent input method activation entirely
            // This is the most aggressive approach to prevent ViewBridge connections
        }
        
        // Additional safety: disable rich text features
        editor.allowsUndo = false
        editor.isRichText = false
        editor.importsGraphics = false
        
        // Force plain text mode
        editor.isEditable = true
        editor.isSelectable = true
    }
    
    // Override acceptsFirstResponder to ensure we can still receive focus
    override var acceptsFirstResponder: Bool {
        return true
    }
}