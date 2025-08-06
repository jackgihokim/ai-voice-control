//
//  PermissionManager.swift
//  AIVoiceControl
//
//  Created by Jack Kim on 8/4/25.
//

import Foundation
import Speech
import AVFoundation
import ApplicationServices
import AppKit

@MainActor
class PermissionManager: ObservableObject {
    
    static let shared = PermissionManager()
    
    @Published var microphonePermissionStatus: PermissionStatus = .notDetermined
    @Published var speechRecognitionPermissionStatus: PermissionStatus = .notDetermined
    @Published var accessibilityPermissionStatus: PermissionStatus = .notDetermined
    @Published var automationPermissionStatus: PermissionStatus = .notDetermined
    
    private var permissionCheckTimer: Timer?
    
    private init() {
        updateAllPermissionStatuses()
        startPermissionMonitoring()
    }
    
    deinit {
        permissionCheckTimer?.invalidate()
    }
    
    // MARK: - Permission Status Updates
    
    func updateAllPermissionStatuses() {
        updateMicrophonePermissionStatus()
        updateSpeechRecognitionPermissionStatus()
        updateAccessibilityPermissionStatus()
        updateAutomationPermissionStatus()
    }
    
    private func updateMicrophonePermissionStatus() {
        #if os(macOS)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        #if DEBUG
        print("🎤 Updating microphone permission status: \(status)")
        print("🎤 Raw status value: \(status.rawValue)")
        print("🔍 Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        print("🔍 Executable path: \(Bundle.main.executablePath ?? "Unknown")")
        print("🔍 Main bundle path: \(Bundle.main.bundlePath)")
        #endif
        
        switch status {
        case .authorized:
            microphonePermissionStatus = .authorized
        case .denied:
            microphonePermissionStatus = .denied
        case .restricted:
            microphonePermissionStatus = .restricted
        case .notDetermined:
            microphonePermissionStatus = .notDetermined
        @unknown default:
            microphonePermissionStatus = .notDetermined
        }
        #else
        microphonePermissionStatus = AVAudioSession.sharedInstance().recordPermission.permissionStatus
        #endif
    }
    
    private func updateSpeechRecognitionPermissionStatus() {
        speechRecognitionPermissionStatus = SFSpeechRecognizer.authorizationStatus().permissionStatus
    }
    
    private func updateAccessibilityPermissionStatus() {
        // First check with AXIsProcessTrusted
        let trusted = AXIsProcessTrusted()
        
        if trusted {
            accessibilityPermissionStatus = .authorized
            return
        }
        
        // If not trusted, try a more comprehensive check
        // Sometimes AXIsProcessTrusted returns false even when permission is granted
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue()
        let options = [key: false] as CFDictionary
        let trustedWithOptions = AXIsProcessTrustedWithOptions(options)
        
        if trustedWithOptions {
            accessibilityPermissionStatus = .authorized
            return
        }
        
        // Final check: try to get the system-wide element
        // If this succeeds, we have accessibility permission
        let systemElement = AXUIElementCreateSystemWide()
        var focusedApp: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        
        if result == .success {
            accessibilityPermissionStatus = .authorized
        } else {
            accessibilityPermissionStatus = .denied
        }
        
        #if DEBUG
        print("🔐 Accessibility Permission Check:")
        print("   AXIsProcessTrusted(): \(trusted)")
        print("   AXIsProcessTrustedWithOptions(): \(trustedWithOptions)")
        print("   AXUIElementCopyAttributeValue result: \(result)")
        print("   Final status: \(accessibilityPermissionStatus)")
        #endif
    }
    
    private func updateAutomationPermissionStatus() {
        // Automation permission is handled per-app and requested when first used
        // For now, assume it's available (will be checked when actually needed)
        automationPermissionStatus = .authorized
    }
    
    // MARK: - Permission Requests
    
    func requestMicrophonePermission() async -> PermissionStatus {
        return await withCheckedContinuation { continuation in
            #if os(macOS)
            // Check current status first
            let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
            
            #if DEBUG
            print("🎤 === MICROPHONE PERMISSION REQUEST DEBUG ===")
            print("🎤 Current microphone permission status: \(currentStatus) (raw: \(currentStatus.rawValue))")
            print("🔍 Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
            print("🔍 Bundle path: \(Bundle.main.bundlePath)")
            print("🔍 Executable path: \(Bundle.main.executablePath ?? "Unknown")")
            let isMenuBarOnly = Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool ?? false
            print("🔍 App is menu bar only: \(isMenuBarOnly)")
            print("🔍 Process name: \(ProcessInfo.processInfo.processName)")
            print("🔍 Process ID: \(ProcessInfo.processInfo.processIdentifier)")
            print("🎤 ==========================================")
            #endif
            
            switch currentStatus {
            case .authorized:
                DispatchQueue.main.async {
                    self.microphonePermissionStatus = .authorized
                    continuation.resume(returning: .authorized)
                }
            case .denied, .restricted:
                DispatchQueue.main.async {
                    self.microphonePermissionStatus = .denied
                    continuation.resume(returning: .denied)
                }
            case .notDetermined:
                #if DEBUG
                print("🎤 Microphone permission is notDetermined, requesting...")
                print("🎤 About to call AVCaptureDevice.requestAccess...")
                #endif
                
                // SOLUTION: For menu bar apps, permission dialogs may not appear
                // The app should be temporarily configured as a regular app during first launch
                // to ensure permission dialogs work properly
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    #if DEBUG
                    print("🎤 === PERMISSION REQUEST CALLBACK ===")
                    print("🎤 AVCaptureDevice.requestAccess result: \(granted)")
                    print("🎤 New permission status: \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue)")
                    if !granted {
                        print("⚠️ Permission request failed - likely due to LSUIElement configuration or system policy")
                        print("💡 Solution: Remove LSUIElement temporarily during first launch")
                    } else {
                        print("✅ Permission granted successfully!")
                    }
                    print("🎤 ================================")
                    #endif
                    
                    DispatchQueue.main.async {
                        let status: PermissionStatus = granted ? .authorized : .denied
                        self.microphonePermissionStatus = status
                        continuation.resume(returning: status)
                    }
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.microphonePermissionStatus = .notDetermined
                    continuation.resume(returning: .notDetermined)
                }
            }
            #else
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    let status: PermissionStatus = granted ? .authorized : .denied
                    self.microphonePermissionStatus = status
                    continuation.resume(returning: status)
                }
            }
            #endif
        }
    }
    
    #if os(macOS)
    private func triggerMicrophonePermissionDialog(completion: @escaping (PermissionStatus) -> Void) {
        #if DEBUG
        print("🎤 Triggering microphone permission dialog...")
        #endif
        
        // Try Speech Recognition approach first - this often triggers microphone permission
        self.trySpeechRecognitionPermission { microphoneStatus in
            if microphoneStatus == .authorized {
                completion(.authorized)
            } else {
                // Fall back to AVCaptureDevice
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    #if DEBUG
                    print("🎤 AVCaptureDevice.requestAccess result: \(granted)")
                    #endif
                    
                    if granted {
                        DispatchQueue.main.async {
                            completion(.authorized)
                        }
                    } else {
                        // Last resort: try AVAudioRecorder
                        self.tryAudioRecorderPermission(completion: completion)
                    }
                }
            }
        }
    }
    
    private func trySpeechRecognitionPermission(completion: @escaping (PermissionStatus) -> Void) {
        #if DEBUG
        print("🎤 Trying Speech Recognition to trigger microphone permission...")
        #endif
        
        // Request speech recognition permission, which often triggers microphone permission
        SFSpeechRecognizer.requestAuthorization { authStatus in
            #if DEBUG
            print("🎤 Speech recognition permission result: \(authStatus)")
            #endif
            
            // Check if this also granted microphone permission
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                #if DEBUG
                print("🎤 Microphone status after speech recognition request: \(micStatus)")
                #endif
                
                let permissionStatus: PermissionStatus = micStatus == .authorized ? .authorized : .denied
                completion(permissionStatus)
            }
        }
    }
    
    private func tryAudioRecorderPermission(completion: @escaping (PermissionStatus) -> Void) {
        #if DEBUG
        print("🎤 Trying AVAudioRecorder approach...")
        #endif
        
        do {
            // Create a minimal audio recorder setup
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_mic_check.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            
            let recorder = try AVAudioRecorder(url: tempURL, settings: settings)
            recorder.prepareToRecord()
            
            // Try to record for a very short time
            if recorder.record(forDuration: 0.1) {
                #if DEBUG
                print("🎤 AVAudioRecorder started successfully")
                #endif
                
                // Stop immediately
                recorder.stop()
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: tempURL)
                
                // Check permission status
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let status = AVCaptureDevice.authorizationStatus(for: .audio)
                    let permissionStatus: PermissionStatus = status == .authorized ? .authorized : .denied
                    
                    #if DEBUG
                    print("🎤 Final permission status: \(status)")
                    #endif
                    
                    completion(permissionStatus)
                }
            } else {
                #if DEBUG
                print("🎤 AVAudioRecorder failed to start")
                #endif
                
                DispatchQueue.main.async {
                    completion(.denied)
                }
            }
        } catch {
            #if DEBUG
            print("🎤 AVAudioRecorder setup failed: \(error)")
            #endif
            
            DispatchQueue.main.async {
                completion(.denied)
            }
        }
    }
    #endif
    
    func requestSpeechRecognitionPermission() async -> PermissionStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    let permissionStatus = status.permissionStatus
                    self.speechRecognitionPermissionStatus = permissionStatus
                    continuation.resume(returning: permissionStatus)
                }
            }
        }
    }
    
    func requestAccessibilityPermission() -> PermissionStatus {
        // Accessibility permission must be granted manually by the user in System Preferences
        // We can only check the current status and guide the user to System Preferences
        updateAccessibilityPermissionStatus()
        return accessibilityPermissionStatus
    }
    
    func requestAutomationPermission() -> PermissionStatus {
        // Automation permission is granted on a per-app basis when first accessed
        // We'll update this when we actually try to use AppleScript
        updateAutomationPermissionStatus()
        return automationPermissionStatus
    }
    
    // MARK: - Permission Check Methods
    
    func checkMicrophonePermission() async -> PermissionStatus {
        updateMicrophonePermissionStatus()
        return microphonePermissionStatus
    }
    
    func checkSpeechRecognitionPermission() async -> PermissionStatus {
        updateSpeechRecognitionPermissionStatus()
        return speechRecognitionPermissionStatus
    }
    
    // MARK: - Helper Methods
    
    func areAllCriticalPermissionsGranted() -> Bool {
        // Only check microphone and speech recognition as critical for basic functionality
        return microphonePermissionStatus == .authorized &&
               speechRecognitionPermissionStatus == .authorized
    }
    
    func openSystemPreferences(for permissionType: PermissionType) {
        switch permissionType {
        case .microphone:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        case .speechRecognition:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
                NSWorkspace.shared.open(url)
            }
        case .accessibility:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        case .automation:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    // MARK: - Permission Monitoring
    
    private func startPermissionMonitoring() {
        // 2초마다 권한 상태 확인
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAllPermissionStatuses()
            }
        }
        
        #if DEBUG
        print("📡 Permission monitoring started - checking every 2 seconds")
        #endif
    }
    
    func stopPermissionMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        
        #if DEBUG
        print("📡 Permission monitoring stopped")
        #endif
    }
    
    func resumePermissionMonitoring() {
        if permissionCheckTimer == nil {
            startPermissionMonitoring()
        }
    }
}

// MARK: - Supporting Enums

enum PermissionStatus: String, CaseIterable {
    case notDetermined = "Not Determined"
    case authorized = "Authorized"
    case denied = "Denied"
    case restricted = "Restricted"
    
    var isGranted: Bool {
        return self == .authorized
    }
    
    var description: String {
        switch self {
        case .notDetermined:
            return "Permission has not been requested yet"
        case .authorized:
            return "Permission granted"
        case .denied:
            return "Permission denied"
        case .restricted:
            return "Permission restricted by system policy"
        }
    }
}

enum PermissionType: String, CaseIterable {
    case microphone = "Microphone"
    case speechRecognition = "Speech Recognition"
    case accessibility = "Accessibility"
    case automation = "Automation"
    
    var systemName: String {
        switch self {
        case .microphone:
            return "mic.circle"
        case .speechRecognition:
            return "waveform"
        case .accessibility:
            return "hand.raised"
        case .automation:
            return "gear"
        }
    }
    
    var description: String {
        switch self {
        case .microphone:
            return "Required for voice input and recording"
        case .speechRecognition:
            return "Required for converting speech to text"
        case .accessibility:
            return "Required for controlling other applications"
        case .automation:
            return "Required for terminal and app automation"
        }
    }
}

// MARK: - Extensions

extension SFSpeechRecognizerAuthorizationStatus {
    var permissionStatus: PermissionStatus {
        switch self {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .authorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }
}