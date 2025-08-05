import Foundation
import Speech
import AVFoundation

@MainActor
class VoiceRecognitionEngine: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var currentTranscription = ""
    @Published var error: VoiceRecognitionError?
    @Published var audioLevel: Float = 0.0
    @Published var recognitionState: RecognitionState = .idle
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioLevelTimer: Timer?
    
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
    init(locale: Locale = Locale(identifier: "ko-KR"), requiresOnDeviceRecognition: Bool = false) {
        self.locale = locale
        self.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        super.init()
        setupSpeechRecognizer()
    }
    
    deinit {
        Task { @MainActor in
            stopListening()
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
    
    // MARK: - Public Methods
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
            try await startAudioEngine()
            recognitionState = .listening
            isListening = true
            startAudioLevelMonitoring()
            
            #if DEBUG
            print("✅ Voice recognition started")
            #endif
        } catch {
            recognitionState = .idle
            throw VoiceRecognitionError.audioEngineError
        }
    }
    
    func stopListening() {
        guard recognitionState == .listening else { return }
        
        recognitionState = .stopping
        
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest = nil
        recognitionTask = nil
        
        stopAudioLevelMonitoring()
        
        isListening = false
        recognitionState = .idle
        audioLevel = 0.0
        
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
    
    // MARK: - Private Methods
    private func startAudioEngine() async throws {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceRecognitionError.audioEngineError
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        
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
            let transcription = result.bestTranscription.formattedString
            currentTranscription = transcription
            
            if result.isFinal {
                recognizedText = transcription
                #if DEBUG
                print("📝 Final: \(transcription)")
                #endif
                
                // Restart recognition for continuous listening
                if isListening {
                    Task {
                        stopListening()
                        try? await startListening()
                    }
                }
            } else {
                #if DEBUG
                print("📝 Partial: \(transcription)")
                #endif
            }
        }
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