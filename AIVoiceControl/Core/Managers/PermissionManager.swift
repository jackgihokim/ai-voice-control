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
        
        let newPermissionStatus: PermissionStatus
        switch status {
        case .authorized:
            newPermissionStatus = .authorized
        case .denied:
            newPermissionStatus = .denied
        case .restricted:
            newPermissionStatus = .restricted
        case .notDetermined:
            newPermissionStatus = .notDetermined
        @unknown default:
            newPermissionStatus = .notDetermined
        }
        
        #if DEBUG
        // 권한 상태가 변경되었을 때만 로그 출력
        if newPermissionStatus != microphonePermissionStatus {
            print("🎤 Microphone permission status changed: \(status)")
            print("🎤 Raw status value: \(status.rawValue)")
            print("🔍 Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
            print("🔍 New permission status: \(newPermissionStatus)")
        }
        #endif
        
        microphonePermissionStatus = newPermissionStatus
        #else
        microphonePermissionStatus = AVAudioSession.sharedInstance().recordPermission.permissionStatus
        #endif
    }
    
    private func updateSpeechRecognitionPermissionStatus() {
        speechRecognitionPermissionStatus = SFSpeechRecognizer.authorizationStatus().permissionStatus
    }
    
    private func updateAccessibilityPermissionStatus() {
        // 정확한 권한 체크: AXIsProcessTrusted만 사용
        let trusted = AXIsProcessTrusted()
        
        // 첫 실행시에는 notDetermined 상태를 유지
        let newPermissionStatus: PermissionStatus
        if accessibilityPermissionStatus == .notDetermined && !trusted {
            // 처음 실행하고 권한이 없으면 notDetermined 유지
            newPermissionStatus = .notDetermined
        } else {
            // 권한 요청 후 또는 이미 권한이 있으면 정확한 상태 반영
            newPermissionStatus = trusted ? .authorized : .denied
        }
        
        #if DEBUG
        // 권한 상태가 변경되었을 때만 로그 출력 (마이크 권한과 동일한 패턴)
        if newPermissionStatus != accessibilityPermissionStatus {
            print("🔐 Accessibility Permission Status Changed:")
            print("   AXIsProcessTrusted(): \(trusted)")
            print("   Previous status: \(accessibilityPermissionStatus)")
            print("   New status: \(newPermissionStatus)")
        }
        #endif
        
        accessibilityPermissionStatus = newPermissionStatus
    }
    
    private func updateAutomationPermissionStatus() {
        // Automation permission is handled per-app and requested when first used
        // 첫 실행시에는 notDetermined 상태 유지
        if automationPermissionStatus == .notDetermined {
            // 처음 실행시에는 notDetermined 유지 (Request Permission 버튼 표시용)
            automationPermissionStatus = .notDetermined
        }
        // 실제 권한 체크는 AppleScript 실행시에 수행
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
        // Show the permission dialog to guide the user
        
        #if DEBUG
        print("🔐 Requesting Accessibility permission...")
        #endif
        
        // 권한 요청 다이얼로그 표시
        let checkOptionKey = kAXTrustedCheckOptionPrompt.takeRetainedValue()
        let options = [checkOptionKey: true] as CFDictionary  // true로 설정해서 다이얼로그 표시
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        // 권한 요청 후 상태 업데이트
        if trusted {
            accessibilityPermissionStatus = .authorized
        } else {
            // 권한 요청 후에는 denied로 변경 (사용자가 시스템 설정에서 승인해야 함)
            accessibilityPermissionStatus = .denied
        }
        
        #if DEBUG
        print("🔐 Accessibility permission result: \(accessibilityPermissionStatus)")
        #endif
        
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
        // 모든 권한이 승인되었으면 모니터링 중지
        if areAllCriticalPermissionsGranted() {
            #if DEBUG
            print("📡 All permissions granted - no monitoring needed")
            #endif
            return
        }
        
        // 2초마다 권한 상태 확인
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAllPermissionStatuses()
                
                // 모든 권한이 승인되면 타이머 중지
                if let self = self, self.areAllCriticalPermissionsGranted() {
                    #if DEBUG
                    print("📡 All permissions granted - stopping monitoring")
                    #endif
                    self.stopPermissionMonitoring()
                }
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