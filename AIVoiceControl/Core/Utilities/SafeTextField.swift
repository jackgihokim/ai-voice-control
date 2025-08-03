//
//  SafeTextField.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import AppKit

struct SafeTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let width: CGFloat?
    
    init(_ placeholder: String, text: Binding<String>, width: CGFloat? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.width = width
    }
    
    func makeNSView(context: Context) -> NoInputMethodTextField {
        let textField = NoInputMethodTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        
        // Comprehensive input method and ViewBridge prevention
        textField.allowsEditingTextAttributes = false
        textField.importsGraphics = false
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        
        // Disable focus ring to prevent ViewBridge connections
        textField.focusRingType = .none
        
        // Create a completely custom cell to avoid system input services
        let cell = NoInputMethodTextFieldCell()
        cell.isBordered = true
        cell.bezelStyle = .roundedBezel
        cell.isEditable = true
        cell.isSelectable = true
        cell.wraps = false
        cell.isScrollable = true
        textField.cell = cell
        
        if let width = width {
            textField.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NoInputMethodTextField, context: Context) {
        nsView.stringValue = text
        nsView.placeholderString = placeholder
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: SafeTextField
        
        init(_ parent: SafeTextField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
        
        func textShouldBeginEditing(_ textObject: NSText) -> Bool {
            // Comprehensive input method disabling
            if let textView = textObject as? NSTextView {
                // Disable all automatic text features that might trigger ViewBridge
                textView.isAutomaticTextCompletionEnabled = false
                textView.isAutomaticSpellingCorrectionEnabled = false
                textView.isAutomaticQuoteSubstitutionEnabled = false
                textView.isAutomaticDashSubstitutionEnabled = false
                textView.isAutomaticTextReplacementEnabled = false
                textView.isAutomaticLinkDetectionEnabled = false
                textView.isAutomaticDataDetectionEnabled = false
                
                // Disable grammar checking and data detectors
                textView.isGrammarCheckingEnabled = false
                textView.isAutomaticDataDetectionEnabled = false
                
                // Force disable input method context completely
                textView.inputContext?.discardMarkedText()
                textView.inputContext?.invalidateCharacterCoordinates()
                // Note: inputContext is read-only, so we can't set it to nil
            }
            return true
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            // Additional safety when editing begins
            if let textField = notification.object as? NSTextField,
               let fieldEditor = textField.currentEditor() as? NSTextView {
                
                // Double-check all input method services are disabled
                fieldEditor.isAutomaticTextCompletionEnabled = false
                fieldEditor.isAutomaticSpellingCorrectionEnabled = false
                fieldEditor.isAutomaticQuoteSubstitutionEnabled = false
                fieldEditor.isAutomaticDashSubstitutionEnabled = false
                fieldEditor.isAutomaticTextReplacementEnabled = false
                fieldEditor.isAutomaticLinkDetectionEnabled = false
                fieldEditor.isAutomaticDataDetectionEnabled = false
                fieldEditor.isGrammarCheckingEnabled = false
                
                // Force clear any pending input method state
                fieldEditor.inputContext?.discardMarkedText()
                fieldEditor.inputContext?.invalidateCharacterCoordinates()
            }
        }
    }
}

// MARK: - Custom TextField Classes

/// Custom NSTextField that completely disables input method services
class NoInputMethodTextField: NSTextField {
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        
        // Immediately disable input context when becoming first responder
        if let fieldEditor = currentEditor() as? NSTextView {
            configureFieldEditor(fieldEditor)
        }
        
        return result
    }
    
    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        
        // Configure field editor when text editing begins
        if let fieldEditor = currentEditor() as? NSTextView {
            configureFieldEditor(fieldEditor)
        }
    }
    
    private func configureFieldEditor(_ fieldEditor: NSTextView) {
        // Comprehensive input method disabling
        fieldEditor.isAutomaticTextCompletionEnabled = false
        fieldEditor.isAutomaticSpellingCorrectionEnabled = false
        fieldEditor.isAutomaticQuoteSubstitutionEnabled = false
        fieldEditor.isAutomaticDashSubstitutionEnabled = false
        fieldEditor.isAutomaticTextReplacementEnabled = false
        fieldEditor.isAutomaticLinkDetectionEnabled = false
        fieldEditor.isAutomaticDataDetectionEnabled = false
        fieldEditor.isGrammarCheckingEnabled = false
        fieldEditor.isContinuousSpellCheckingEnabled = false
        
        // Force clear input context to prevent ViewBridge connections
        fieldEditor.inputContext?.discardMarkedText()
        fieldEditor.inputContext?.invalidateCharacterCoordinates()
        
        // This is the nuclear option - completely disable input context
        // This prevents ViewBridge from trying to connect to remote services
        if let inputContext = fieldEditor.inputContext {
            inputContext.discardMarkedText()
            inputContext.invalidateCharacterCoordinates()
            // Don't set to nil as it might cause other issues, but clear its state
        }
    }
}

/// Custom NSTextFieldCell that avoids input method services
class NoInputMethodTextFieldCell: NSTextFieldCell {
    
    override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        let fieldEditor = super.setUpFieldEditorAttributes(textObj)
        
        // Configure the field editor to avoid input methods
        if let textView = fieldEditor as? NSTextView {
            textView.isAutomaticTextCompletionEnabled = false
            textView.isAutomaticSpellingCorrectionEnabled = false
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
            textView.isAutomaticLinkDetectionEnabled = false
            textView.isAutomaticDataDetectionEnabled = false
            textView.isGrammarCheckingEnabled = false
            textView.isContinuousSpellCheckingEnabled = false
            
            // Clear input context immediately
            textView.inputContext?.discardMarkedText()
            textView.inputContext?.invalidateCharacterCoordinates()
        }
        
        return fieldEditor
    }
}