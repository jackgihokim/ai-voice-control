import Foundation
import Speech
import AVFoundation

extension Notification.Name {
    static let voiceIsolationStateChanged = Notification.Name("voiceIsolationStateChanged")
}

@MainActor
class VoiceRecognitionEngine: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var currentTranscription = ""
    @Published var error: VoiceRecognitionError?
    @Published var audioLevel: Float = 0.0
    @Published var recognitionState: RecognitionState = .idle
    @Published var isVoiceIsolationEnabled = false
    @Published var audioQuality: VoiceIsolationManager.AudioQuality = .unknown
    @Published var isWaitingForCommand: Bool = false
    @Published var detectedApp: AppConfiguration?
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioLevelTimer: Timer?
    private lazy var voiceIsolationManager = VoiceIsolationManager()
    private let wakeWordDetector = WakeWordDetector()
    
    // Continuous recognition management
    private var restartTimer: Timer?
    private let maxContinuousTime: TimeInterval = 59.0 // Stay under 60s Apple limit
    private var isRestarting = false
    
    // MARK: - Configuration
    private let locale: Locale
    private let requiresOnDeviceRecognition: Bool
    
    // MARK: - Types
    enum RecognitionState {
        case idle
        case starting
        case listening
        case processing
        case stopping
    }
    
    enum VoiceRecognitionError: LocalizedError {
        case speechRecognizerUnavailable
        case noMicrophoneAccess
        case audioEngineError
        case recognitionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .speechRecognizerUnavailable:
                return "Speech recognizer is not available"
            case .noMicrophoneAccess:
                return "Microphone access denied"
            case .audioEngineError:
                return "Audio engine failed to start"
            case .recognitionFailed(let message):
                return "Recognition failed: \(message)"
            }
        }
    }
    
    // MARK: - Initialization
    init(locale: Locale = Locale(identifier: "ko-KR"), requiresOnDeviceRecognition: Bool = true) {
        self.locale = locale
        self.requiresOnDeviceRecognition = requiresOnDeviceRecognition // Enable on-device to bypass 1-minute limit
        super.init()
        setupSpeechRecognizer()
        setupVoiceIsolationBinding()
        setupWakeWordDetector()
    }
    
    deinit {
        Task { @MainActor in
            stopListening()
            restartTimer?.invalidate()
            restartTimer = nil
        }
    }
    
    // MARK: - Setup
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.delegate = self
        
        if requiresOnDeviceRecognition {
            speechRecognizer?.supportsOnDeviceRecognition = true
        }
        
        #if DEBUG
        print("🎤 Speech recognizer initialized")
        print("🎤 Locale: \(locale.identifier)")
        print("🎤 On-device recognition: \(speechRecognizer?.supportsOnDeviceRecognition ?? false)")
        print("🎤 Available: \(speechRecognizer?.isAvailable ?? false)")
        #endif
    }
    
    private func setupVoiceIsolationBinding() {
        // Don't initialize VoiceIsolationManager immediately to avoid interfering with permissions
        // Initialize default values
        isVoiceIsolationEnabled = UserDefaults.standard.bool(forKey: "VoiceIsolationEnabled")
        audioQuality = .unknown
        
        // Listen for changes in the voice isolation manager
        Task {
            for await _ in NotificationCenter.default.notifications(named: .voiceIsolationStateChanged) {
                await MainActor.run {
                    isVoiceIsolationEnabled = voiceIsolationManager.isVoiceIsolationEnabled
                    audioQuality = voiceIsolationManager.audioQuality
                }
            }
        }
    }
    
    private func setupWakeWordDetector() {
        // Bind wake word detector state to our published properties
        Task {
            for await _ in wakeWordDetector.$isWaitingForCommand.values {
                isWaitingForCommand = wakeWordDetector.isWaitingForCommand
            }
        }
        
        Task {
            for await _ in wakeWordDetector.$detectedApp.values {
                detectedApp = wakeWordDetector.detectedApp
            }
        }
    }
    
    // MARK: - Public Methods
    func resetWakeWordState() {
        wakeWordDetector.resetState()
    }
    
    func startListening() async throws {
        guard recognitionState == .idle else {
            #if DEBUG
            print("⚠️ Already listening or processing")
            #endif
            return
        }
        
        recognitionState = .starting
        
        // Check microphone permission
        let microphoneStatus = await PermissionManager.shared.checkMicrophonePermission()
        guard microphoneStatus == .authorized else {
            recognitionState = .idle
            throw VoiceRecognitionError.noMicrophoneAccess
        }
        
        // Check speech recognition permission
        let speechStatus = await PermissionManager.shared.checkSpeechRecognitionPermission()
        guard speechStatus == .authorized else {
            recognitionState = .idle
            throw VoiceRecognitionError.speechRecognizerUnavailable
        }
        
        // Check if speech recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            recognitionState = .idle
            throw VoiceRecognitionError.speechRecognizerUnavailable
        }
        
        do {
            // Configure voice isolation based on user settings
            await configureVoiceIsolation()
            
            try await startAudioEngine()
            recognitionState = .listening
            isListening = true
            startAudioLevelMonitoring()
            
            // Schedule automatic restart for continuous recognition
            scheduleAutomaticRestart()
            
            #if DEBUG
            print("✅ Voice recognition started")
            print("🔊 Voice Isolation: \(isVoiceIsolationEnabled ? "Enabled" : "Disabled")")
            print("⏰ Automatic restart scheduled in \(maxContinuousTime) seconds")
            #endif
        } catch {
            recognitionState = .idle
            throw VoiceRecognitionError.audioEngineError
        }
    }
    
    func stopListening() {
        guard recognitionState == .listening else { return }
        
        recognitionState = .stopping
        
        // Cancel restart timer
        restartTimer?.invalidate()
        restartTimer = nil
        
        // Clean up recognition resources
        cleanupRecognitionTask()
        
        stopAudioLevelMonitoring()
        
        // Clean up voice isolation only if it was initialized
        if isVoiceIsolationEnabled {
            Task {
                try? await voiceIsolationManager.cleanupAudioSession()
            }
        }
        
        isListening = false
        recognitionState = .idle
        audioLevel = 0.0
        isRestarting = false
        
        #if DEBUG
        print("🛑 Voice recognition stopped")
        #endif
    }
    
    func switchLanguage(to locale: Locale) {
        let wasListening = isListening
        
        if wasListening {
            stopListening()
        }
        
        setupSpeechRecognizer()
        
        if wasListening {
            Task {
                try? await startListening()
            }
        }
    }
    
    func updateVoiceIsolationSettings(enabled: Bool) async throws {
        if enabled && !isVoiceIsolationEnabled {
            try await voiceIsolationManager.enableVoiceIsolation()
        } else if !enabled && isVoiceIsolationEnabled {
            try await voiceIsolationManager.disableVoiceIsolation()
        }
        
        // Update our published properties
        isVoiceIsolationEnabled = voiceIsolationManager.isVoiceIsolationEnabled
        audioQuality = voiceIsolationManager.audioQuality
        
        // Post notification for other listeners
        NotificationCenter.default.post(name: .voiceIsolationStateChanged, object: nil)
    }
    
    // MARK: - Private Methods
    
    private func configureVoiceIsolation() async {
        // Only configure voice isolation if we have microphone permission
        // This prevents interference with permission requests
        let microphoneStatus = await PermissionManager.shared.checkMicrophonePermission()
        guard microphoneStatus == .authorized else {
            #if DEBUG
            print("🔊 Skipping voice isolation configuration - no microphone permission")
            #endif
            isVoiceIsolationEnabled = false
            audioQuality = .unknown
            return
        }
        
        // Check user settings for voice isolation preference
        let userSettings = UserSettings.load()
        
        do {
            if userSettings.enableVoiceIsolation {
                try await voiceIsolationManager.configureForVoiceRecognition()
                // Update our published properties
                isVoiceIsolationEnabled = voiceIsolationManager.isVoiceIsolationEnabled
                audioQuality = voiceIsolationManager.audioQuality
            } else {
                isVoiceIsolationEnabled = false
                audioQuality = .good
            }
        } catch {
            #if DEBUG
            print("⚠️ Voice isolation configuration failed: \(error)")
            #endif
            // Continue without voice isolation
            isVoiceIsolationEnabled = false
            audioQuality = .unknown
        }
    }
    private func startAudioEngine() async throws {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceRecognitionError.audioEngineError
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        
        #if DEBUG
        print("🎙️ Speech recognition request configured:")
        print("   On-device recognition: \(requiresOnDeviceRecognition)")
        if let speechRecognizer = speechRecognizer {
            print("   Supports on-device: \(speechRecognizer.supportsOnDeviceRecognition)")
        }
        #endif
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate audio level
            if let self = self {
                let level = self.calculateAudioLevel(buffer: buffer)
                Task { @MainActor in
                    self.audioLevel = level
                }
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            #if DEBUG
            print("❌ Recognition error: \(error)")
            #endif
            self.error = .recognitionFailed(error.localizedDescription)
            
            // Restart if it's a temporary error
            if (error as NSError).code == 203 { // Server error
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    if isListening {
                        stopListening()
                        try? await startListening()
                    }
                }
            }
        }
        
        if let result = result {
            var transcription = result.bestTranscription.formattedString
            
            // Load user settings once
            let userSettings = UserSettings.load()
            
            // 구두점 자동 추가 (사용자 설정에 따라)
            // 웨이크워드 감지 상태에서는 부분 결과에도 구두점 추가 (실시간 표시용)
            let shouldAddPunctuation = userSettings.autoAddPunctuation && 
                (result.isFinal || wakeWordDetector.isWaitingForCommand)
            
            if shouldAddPunctuation {
                let originalText = transcription
                
                // 텍스트가 너무 짧으면 구두점 추가하지 않음 (오판 방지)
                if transcription.count >= 3 || result.isFinal {
                    transcription = KoreanPunctuationHelper.addPunctuation(
                        to: transcription,
                        style: userSettings.punctuationStyle == .none ? .none : 
                               userSettings.punctuationStyle == .aggressive ? 
                               KoreanPunctuationHelper.PunctuationStyle.aggressive : 
                               KoreanPunctuationHelper.PunctuationStyle.conservative
                    )
                }
                
                #if DEBUG
                if originalText != transcription {
                    let endingType = KoreanPunctuationHelper.detectEndingType(originalText)
                    print("📝 Punctuation processing:")
                    print("   Original: '\(originalText)'")
                    print("   Modified: '\(transcription)'")
                    print("   Type detected: \(endingType)")
                    print("   Style: \(userSettings.punctuationStyle)")
                    print("   Is Final: \(result.isFinal)")
                    print("   Waiting for command: \(wakeWordDetector.isWaitingForCommand)")
                }
                #endif
            } else {
                #if DEBUG
                if result.isFinal && !userSettings.autoAddPunctuation {
                    print("⚠️ Punctuation not added: autoAddPunctuation = \(userSettings.autoAddPunctuation)")
                }
                #endif
            }
            
            currentTranscription = transcription
            
            #if DEBUG
            print("🎤 Processing transcription: '\(transcription)' | Final: \(result.isFinal)")
            print("🔍 Current WakeWordDetector state: \(wakeWordDetector.state)")
            #endif
            
            // Process wake words with current app configurations
            
            #if DEBUG
            let appNames = userSettings.registeredApps.map { $0.name }.joined(separator: ", ")
            print("📱 Registered apps: [\(appNames)]")
            #endif
            
            wakeWordDetector.processTranscription(transcription, apps: userSettings.registeredApps)
            
            if result.isFinal {
                recognizedText = transcription
                
                #if DEBUG
                print("📝 Final: \(transcription)")
                print("💬 Continuing to listen for more speech...")
                #endif
                
                // Clear current transcription for UI display
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.currentTranscription = ""
                }
                
                // isFinal 자동 재시작 제거 - 연속 발화 지원을 위해 세션 유지
                // 59초 타이머가 세션 관리를 담당
            } else {
                #if DEBUG
                if !transcription.isEmpty && transcription.count > 2 {
                    print("📝 Partial: \(transcription)")
                }
                #endif
            }
        }
    }
    
    // MARK: - Continuous Recognition Management
    
    private func scheduleAutomaticRestart() {
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: maxContinuousTime, repeats: false) { _ in
            Task { @MainActor in
                await self.performScheduledRestart()
            }
        }
        
        #if DEBUG
        print("⏰ Scheduled automatic restart in \(maxContinuousTime) seconds")
        #endif
    }
    
    private func performScheduledRestart() async {
        guard isListening && !isRestarting else { return }
        
        // Use async-compatible synchronization instead of semaphore
        isRestarting = true
        defer { isRestarting = false }
        
        #if DEBUG
        print("🔄 Performing scheduled recognition restart")
        #endif
        
        // Stop current recognition
        recognitionState = .stopping
        cleanupRecognitionTask()
        
        // 59초 타이머 만료 시 텍스트 필드도 리셋하도록 알림 전송
        #if DEBUG
        print("🔔 Posting voiceRecognitionReset notification with clearTextField: true")
        #endif
        NotificationCenter.default.post(
            name: .voiceRecognitionReset,
            object: nil,
            userInfo: ["reason": "timerExpired", "clearTextField": true]
        )
        
        // 텍스트 필드 클리어 작업이 완료될 때까지 대기
        // (UI 업데이트: 0.1초 + 선택: 0.1초 + Backspace: 0.05초 + 여유: 0.15초 = 총 0.4초)
        #if DEBUG
        print("⏳ Waiting 0.4 seconds for text field clear to complete...")
        #endif
        try? await Task.sleep(nanoseconds: 400_000_000) // 0.4초
        
        // Restart if still supposed to be listening
        if isListening {
            do {
                recognitionState = .starting
                try await startAudioEngine()
                recognitionState = .listening
                scheduleAutomaticRestart() // Schedule next restart
                
                #if DEBUG
                print("✅ Recognition restarted successfully")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to restart recognition: \(error)")
                #endif
                recognitionState = .idle
                isListening = false
                self.error = .audioEngineError
            }
        }
    }
    
    private func cleanupRecognitionTask() {
        #if DEBUG
        print("🧹 Cleaning up recognition task")
        #endif
        
        // 1. Cancel existing task first
        recognitionTask?.cancel()
        
        // 2. End audio request
        recognitionRequest?.endAudio()
        
        // 3. Stop audio engine
        audioEngine.stop()
        
        // 4. Remove audio tap
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // 5. Clear references
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    // MARK: - Audio Level Monitoring
    private func startAudioLevelMonitoring() {
        // Audio level is already monitored through the main audio tap in startAudioEngine
        // We'll calculate the level from the same buffer we use for recognition
    }
    
    private func stopAudioLevelMonitoring() {
        // Audio level monitoring is handled in the main audio tap
    }
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
            .map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        
        return max(0, min(1, (avgPower + 60) / 60))
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension VoiceRecognitionEngine: @preconcurrency SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        #if DEBUG
        print("🎤 Speech recognizer availability changed: \(available)")
        #endif
        
        if !available {
            Task { @MainActor in
                stopListening()
                error = .speechRecognizerUnavailable
            }
        }
    }
}