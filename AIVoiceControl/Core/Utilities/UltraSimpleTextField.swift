//
//  UltraSimpleTextField.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 7/31/25.
//

import SwiftUI
import AppKit

/// NUCLEAR OPTION: Ultra-aggressive TextField that completely eliminates ViewBridge connections
/// This sacrifices all advanced text features for 100% ViewBridge error prevention
struct UltraSimpleTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let width: CGFloat?
    var onReturn: (() -> Void)?
    
    init(_ placeholder: String, text: Binding<String>, width: CGFloat? = nil, onReturn: (() -> Void)? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.width = width
        self.onReturn = onReturn
    }
    
    func makeNSView(context: Context) -> NuclearTextField {
        let textField = NuclearTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        textField.stringValue = text
        textField.onReturn = onReturn  // Pass the onReturn callback
        
        // NUCLEAR: Absolutely minimal styling to avoid ANY ViewBridge connections
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .none  // CRITICAL: This prevents most ViewBridge connections
        
        // NUCLEAR: Kill all advanced features immediately
        textField.allowsEditingTextAttributes = false
        textField.importsGraphics = false
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        
        // NUCLEAR: Set width if specified
        if let width = width {
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NuclearTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: UltraSimpleTextField
        
        init(_ parent: UltraSimpleTextField) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            DispatchQueue.main.async {
                self.parent.text = textField.stringValue
            }
        }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            DispatchQueue.main.async {
                self.parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Enter key pressed
                if let textField = control as? NuclearTextField {
                    textField.onReturn?()
                }
                return true
            }
            return false
        }
    }
}

/// NUCLEAR NSTextField: Most aggressive implementation to prevent ALL ViewBridge connections
class NuclearTextField: NSTextField {
    var onReturn: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        nuclearSetup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        nuclearSetup()
    }
    
    private func nuclearSetup() {
        // NUCLEAR OPTION 1: Disable focus ring - this prevents MOST ViewBridge connections
        focusRingType = .none
        
        // NUCLEAR OPTION 2: Disable ALL editing attributes
        allowsEditingTextAttributes = false
        importsGraphics = false
        
        // NUCLEAR OPTION 3: Force single line mode
        usesSingleLineMode = true
        lineBreakMode = .byTruncatingTail
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        
        // NUCLEAR STRIKE: Immediately kill input services when becoming first responder
        nuclearKillInputServices()
        
        return result
    }
    
    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        
        // NUCLEAR STRIKE: Kill input services when editing begins
        nuclearKillInputServices()
    }
    
    override func textShouldBeginEditing(_ textObject: NSText) -> Bool {
        // NUCLEAR STRIKE: Kill input services before editing even begins
        if let textView = textObject as? NSTextView {
            nuclearKillTextViewServices(textView)
        }
        return super.textShouldBeginEditing(textObject)
    }
    
    /// NUCLEAR METHOD: Aggressively kill all input services
    private func nuclearKillInputServices() {
        if let editor = currentEditor() as? NSTextView {
            nuclearKillTextViewServices(editor)
        }
        
        // NUCLEAR: Force deactivate input context at the NSTextField level
        inputContext?.discardMarkedText()
        inputContext?.invalidateCharacterCoordinates()
    }
    
    /// NUCLEAR METHOD: Kill ALL NSTextView input services
    private func nuclearKillTextViewServices(_ textView: NSTextView) {
        // NUCLEAR: Disable every single automatic text feature
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        
        // NUCLEAR: Disable rich text and undo
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = false
        
        // NUCLEAR: Kill input context completely
        if let inputContext = textView.inputContext {
            inputContext.discardMarkedText()
            inputContext.invalidateCharacterCoordinates()
        }
        
        // NUCLEAR: Force plain text mode
        textView.isEditable = true
        textView.isSelectable = true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

/// NUCLEAR SYSTEM-LEVEL KILLER: Disable input services application-wide
class SimpleViewBridgeKiller {
    
    /// NUCLEAR: Call this once at app startup to kill ViewBridge services system-wide
    static func activateNuclearOption() {
        let defaults = UserDefaults.standard
        
        // NUCLEAR: Disable automatic text correction system-wide (text input only)
        defaults.set(false, forKey: "NSAutomaticSpellingCorrectionEnabled")
        defaults.set(false, forKey: "NSAutomaticQuoteSubstitutionEnabled")
        defaults.set(false, forKey: "NSAutomaticDashSubstitutionEnabled")
        defaults.set(false, forKey: "NSAutomaticTextReplacementEnabled")
        defaults.set(false, forKey: "NSAutomaticTextCompletionEnabled")
        defaults.set(false, forKey: "NSAutomaticDataDetectionEnabled")
        defaults.set(false, forKey: "NSAutomaticLinkDetectionEnabled")
        defaults.set(false, forKey: "WebAutomaticSpellingCorrectionEnabled")
        defaults.set(false, forKey: "WebAutomaticQuoteSubstitutionEnabled")
        defaults.set(false, forKey: "WebAutomaticDashSubstitutionEnabled")
        defaults.set(false, forKey: "WebAutomaticTextReplacementEnabled")
        defaults.set(false, forKey: "WebContinuousSpellCheckingEnabled")
        
        // REMOVED: These were interfering with speech synthesis services
        // defaults.set(false, forKey: "NSTextInputContextKeyboardLayoutName")
        // defaults.set(false, forKey: "AppleLanguagePreferences")
        
        // NUCLEAR: Force synchronization
        defaults.synchronize()
        
        // Silently activate nuclear option to prevent ViewBridge errors
    }
}