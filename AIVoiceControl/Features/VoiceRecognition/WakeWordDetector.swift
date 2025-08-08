import Foundation

@MainActor
class WakeWordDetector: ObservableObject {
    @Published var isWaitingForCommand = false
    @Published var detectedApp: AppConfiguration?
    @Published var commandBuffer = ""
    
    private var wakeWordTimer: Timer?
    private let commandTimeout: TimeInterval = 5.0
    
    enum DetectionState {
        case idle
        case wakeWordDetected(app: AppConfiguration)
        case waitingForCommand
        case commandReceived
    }
    
    @Published var state: DetectionState = .idle
    
    func processTranscription(_ text: String, apps: [AppConfiguration]) {
        let lowercasedText = text.lowercased()
        
        #if DEBUG
        if !text.isEmpty {
            print("🔍 WakeWordDetector processing: '\(text)' | State: \(state)")
        }
        #endif
        
        switch state {
        case .idle:
            if let app = detectWakeWord(in: lowercasedText, apps: apps) {
                #if DEBUG
                print("🎯 Wake word detected in IDLE state: \(app.name)")
                #endif
                handleWakeWordDetection(app: app)
            }
            
        case .wakeWordDetected(let app):
            // 웨이크 워드로 앱이 활성화된 상태에서는 모든 입력을 명령으로 처리
            // 단, 다른 앱의 웨이크 워드가 감지되면 앱 전환
            
            // 새로운 웨이크 워드가 감지되면 이전 상태를 리셋하고 새로 시작
            if let newApp = detectWakeWord(in: lowercasedText, apps: apps), newApp.id != app.id {
                #if DEBUG
                print("🔄 New wake word detected while waiting for command - switching to: \(newApp.name)")
                #endif
                handleWakeWordDetection(app: newApp)
                return
            }
            
            // 웨이크 워드가 아니면 모든 입력을 명령 버퍼에 저장
            // 실시간 텍스트 입력이 MenuBarViewModel에서 처리됨
            commandBuffer = text
            
            #if DEBUG
            if !text.isEmpty {
                print("📝 Command buffer updated for \(app.name): '\(text)'")
            }
            #endif
            
            // 실시간 텍스트 스트리밍을 위한 알림 전송
            NotificationCenter.default.post(
                name: .commandBufferUpdated,
                object: nil,
                userInfo: [
                    "app": app,
                    "text": text
                ]
            )
            
        case .waitingForCommand:
            commandBuffer = text
            
            // 새로운 웨이크 워드가 감지되면 이전 상태를 리셋하고 새로 시작
            if let newApp = detectWakeWord(in: lowercasedText, apps: apps) {
                if let currentApp = detectedApp, newApp.id != currentApp.id {
                    #if DEBUG
                    print("🔄 New wake word detected while waiting for command - switching to: \(newApp.name)")
                    #endif
                    handleWakeWordDetection(app: newApp)
                    return
                }
            }
            
            // Auto-submit when text gets long enough (no execution words needed)
            if text.count > 200 {
                if let app = detectedApp {
                    handleCommand(app: app)
                } else {
                    resetState()
                }
            }
            
        case .commandReceived:
            // 명령어 처리 완료 후에도 새로운 웨이크 워드를 감지할 수 있게 함
            if let app = detectWakeWord(in: lowercasedText, apps: apps) {
                #if DEBUG
                print("🔄 New wake word detected after command completion - starting: \(app.name)")
                #endif
                handleWakeWordDetection(app: app)
            } else {
                // 새로운 웨이크 워드가 없으면 idle 상태로 돌아감
                resetState()
            }
        }
    }
    
    private func detectWakeWord(in text: String, apps: [AppConfiguration]) -> AppConfiguration? {
        let cleanText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        #if DEBUG
        let availableWakeWords = apps.flatMap { app in
            app.wakeWords.map { "\(app.name): '\($0)'" }
        }
        print("🔎 [IMPROVED] Checking text: '\(text)' against wake words: [\(availableWakeWords.joined(separator: ", "))]")
        #endif
        
        // 웨이크 워드 전용 길이 필터링: 2-10자로 최적화 (성능 향상)
        guard cleanText.count >= FuzzyMatching.minWakeWordLength && 
              cleanText.count <= FuzzyMatching.maxWakeWordLength else {
            #if DEBUG
            print("⚠️ Wake word length out of optimized range: \(cleanText.count) chars (expected: \(FuzzyMatching.minWakeWordLength)-\(FuzzyMatching.maxWakeWordLength))")
            #endif
            return nil
        }
        
        var bestMatch: (app: AppConfiguration, similarity: Double, matchType: String)? = nil
        
        // 각 앱의 웨이크 워드들을 검사
        for app in apps {
            for wakeWord in app.wakeWords {
                let result = FuzzyMatching.matchWakeWord(
                    wakeWord: wakeWord,
                    in: cleanText,
                    threshold: FuzzyMatching.defaultSimilarityThreshold
                )
                
                if result.matched {
                    // 더 높은 유사도 점수가 있으면 업데이트
                    if bestMatch == nil || result.similarity > bestMatch!.similarity {
                        let matchType = result.similarity >= 1.0 ? "exact" : "fuzzy(\(String(format: "%.2f", result.similarity)))"
                        bestMatch = (app, result.similarity, matchType)
                        
                        #if DEBUG
                        print("🎯 Better match found: '\(wakeWord)' for app: \(app.name)")
                        print("   Match type: \(matchType) | Similarity: \(String(format: "%.3f", result.similarity))")
                        #endif
                        
                        // 완벽한 매칭이면 즉시 반환 (최적화)
                        if result.similarity >= 1.0 {
                            #if DEBUG
                            print("✅ Perfect match found - returning immediately")
                            #endif
                            return app
                        }
                    }
                }
            }
        }
        
        // 최고 점수 매칭 결과 반환
        if let match = bestMatch {
            #if DEBUG
            print("✅ Wake word FOUND (\(match.matchType)): '\(match.app.name)'")
            print("   Final similarity: \(String(format: "%.3f", match.similarity))")
            print("   In text: '\(text)'")
            #endif
            return match.app
        }
        
        #if DEBUG
        print("❌ No wake word found in: '\(text)' (no matches above threshold \(FuzzyMatching.defaultSimilarityThreshold))")
        #endif
        return nil
    }
    
    
    private func handleWakeWordDetection(app: AppConfiguration) {
        // 이전 타이머가 있다면 정리
        wakeWordTimer?.invalidate()
        wakeWordTimer = nil
        
        state = .wakeWordDetected(app: app)
        detectedApp = app
        isWaitingForCommand = true  // 웨이크 워드 감지 후 바로 명령 대기 상태로 전환
        commandBuffer = ""
        
        #if DEBUG
        print("🎯 Wake word detected for \(app.name) - ready for real-time text input")
        #endif
        
        // 웨이크 워드 감지 알림 전송
        NotificationCenter.default.post(
            name: .wakeWordDetected,
            object: nil,
            userInfo: ["app": app]
        )
        
        // MenuBarViewModel에서 리셋을 처리하므로 여기서는 하지 않음
        #if DEBUG
        print("📤 Wake word notification sent for \(app.name)")
        #endif
    }
    
    private func handleCommand(app: AppConfiguration) {
        state = .commandReceived
        
        let command = extractCommand(from: commandBuffer, app: app)
        
        #if DEBUG
        print("📋 Command extracted: '\(command)'")
        print("   Original buffer: '\(commandBuffer)'")
        #endif
        
        NotificationCenter.default.post(
            name: .commandReady,
            object: nil,
            userInfo: [
                "app": app,
                "command": command
            ]
        )
        
        resetState()
    }
    
    private func extractCommand(from text: String, app: AppConfiguration) -> String {
        var command = text
        
        for wakeWord in app.wakeWords {
            command = command.replacingOccurrences(
                of: wakeWord,
                with: "",
                options: .caseInsensitive
            )
        }
        
        return command.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func startCommandTimer() {
        wakeWordTimer?.invalidate()
        wakeWordTimer = Timer.scheduledTimer(withTimeInterval: commandTimeout, repeats: false) { _ in
            Task { @MainActor in
                self.handleTimeout()
            }
        }
    }
    
    private func handleTimeout() {
        #if DEBUG
        print("⏱️ Command timeout - resetting state")
        #endif
        
        NotificationCenter.default.post(
            name: .commandTimeout,
            object: nil
        )
        
        resetState()
    }
    
    func resetState() {
        #if DEBUG
        print("🔄 WakeWordDetector: Resetting state to IDLE")
        print("   Previous state: \(state)")
        print("   Was waiting for command: \(isWaitingForCommand)")
        #endif
        
        state = .idle
        isWaitingForCommand = false
        detectedApp = nil
        commandBuffer = ""
        wakeWordTimer?.invalidate()
        wakeWordTimer = nil
        
        #if DEBUG
        print("✅ WakeWordDetector: State reset complete - ready for wake words")
        #endif
    }
}

extension Notification.Name {
    static let wakeWordDetected = Notification.Name("wakeWordDetected")
    static let commandReady = Notification.Name("commandReady")
    static let commandTimeout = Notification.Name("commandTimeout")
    static let commandBufferUpdated = Notification.Name("commandBufferUpdated")
}