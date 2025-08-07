import Foundation
import AppKit

@MainActor
class AppActivator {
    static let shared = AppActivator()
    
    private init() {}
    
    func activateApp(_ appConfig: AppConfiguration) -> Bool {
        #if DEBUG
        print("🚀 Attempting to activate app: \(appConfig.name)")
        print("   Bundle ID: \(appConfig.bundleIdentifier)")
        #endif
        
        // Try to find and activate the app using bundle identifier
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: appConfig.bundleIdentifier).first {
            // Method 1: Direct activation with force
            var success = false
            
            // If app is hidden, unhide it first
            if app.isHidden {
                app.unhide()
                Thread.sleep(forTimeInterval: 0.05)
            }
            
            // Try activating multiple times with different options
            for attempt in 1...3 {
                success = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
                
                if success {
                    #if DEBUG
                    print("✅ Successfully activated \(appConfig.name) on attempt \(attempt)")
                    #endif
                    break
                }
                
                // Small delay between attempts
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            // Method 2: If still not activated, try forcing it to front
            if !success {
                // Set the app as active using a different approach
                NSWorkspace.shared.launchApplication(withBundleIdentifier: appConfig.bundleIdentifier,
                                                     options: [.withoutActivation],
                                                     additionalEventParamDescriptor: nil,
                                                     launchIdentifier: nil)
                Thread.sleep(forTimeInterval: 0.1)
                
                // Now try to activate again
                success = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
                
                #if DEBUG
                if success {
                    print("✅ Successfully activated \(appConfig.name) after re-launch")
                }
                #endif
            }
            
            // Method 3: Use NSWorkspace to bring to front (simpler approach)
            if !success {
                NSWorkspace.shared.launchApplication(withBundleIdentifier: appConfig.bundleIdentifier,
                                                     options: [],
                                                     additionalEventParamDescriptor: nil,
                                                     launchIdentifier: nil)
                success = true // Assume success as this rarely fails
                
                #if DEBUG
                print("✅ Activated \(appConfig.name) using NSWorkspace.launchApplication")
                #endif
            }
            
            #if DEBUG
            if !success {
                print("⚠️ Failed to activate running app: \(appConfig.name)")
            }
            #endif
            
            return success
        }
        
        // If app is not running, try to launch it
        #if DEBUG
        print("📱 App not running, attempting to launch: \(appConfig.name)")
        #endif
        
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appConfig.bundleIdentifier) {
            do {
                let app = try NSWorkspace.shared.launchApplication(at: appURL, options: [.default], configuration: [:])
                
                // Give the app a moment to launch
                Thread.sleep(forTimeInterval: 0.5)
                
                // Try to activate it again
                if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: appConfig.bundleIdentifier).first {
                    let success = runningApp.activate(options: [.activateIgnoringOtherApps])
                    
                    #if DEBUG
                    print("✅ Launched and activated \(appConfig.name)")
                    #endif
                    
                    return success
                }
            } catch {
                #if DEBUG
                print("❌ Failed to launch app: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("❌ Could not find app with bundle ID: \(appConfig.bundleIdentifier)")
            #endif
        }
        
        return false
    }
    
    func isAppRunning(_ appConfig: AppConfiguration) -> Bool {
        return !NSRunningApplication.runningApplications(withBundleIdentifier: appConfig.bundleIdentifier).isEmpty
    }
    
    func bringAppToFront(_ appConfig: AppConfiguration) {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: appConfig.bundleIdentifier).first {
            // Unhide if hidden
            if app.isHidden {
                app.unhide()
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            // Use aggressive activation to bring to front
            let success = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            
            #if DEBUG
            if success {
                print("🔝 Successfully brought \(appConfig.name) to front")
            } else {
                print("⚠️ Failed to bring \(appConfig.name) to front")
            }
            #endif
        }
    }
    
    func getRunningApps() -> [AppConfiguration] {
        let userSettings = UserSettings.load()
        return userSettings.registeredApps.filter { isAppRunning($0) }
    }
    
    func getFrontmostApp() -> AppConfiguration? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        
        let userSettings = UserSettings.load()
        return userSettings.registeredApps.first { 
            $0.bundleIdentifier == frontApp.bundleIdentifier 
        }
    }
    
    /// 앱을 활성화하고 텍스트를 입력합니다
    /// - Parameters:
    ///   - appConfig: 대상 앱 설정
    ///   - text: 입력할 텍스트
    ///   - submitText: true이면 텍스트 입력 후 Enter 키를 전송
    /// - Returns: 성공 여부
    func activateAppAndInputText(_ appConfig: AppConfiguration, text: String, submitText: Bool = false) async -> Bool {
        // 1. 앱 활성화
        guard activateApp(appConfig) else {
            #if DEBUG
            print("❌ Failed to activate app for text input: \(appConfig.name)")
            #endif
            return false
        }
        
        // 2. 앱이 완전히 활성화될 때까지 대기
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3초
        
        // 3. 텍스트 입력
        do {
            if submitText {
                try await TextInputAutomator.shared.inputTextAndSubmit(text, app: appConfig)
            } else {
                try await TextInputAutomator.shared.inputTextToApp(text, app: appConfig)
            }
            
            #if DEBUG
            print("✅ Successfully input text to \(appConfig.name)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("❌ Failed to input text to \(appConfig.name): \(error)")
            #endif
            return false
        }
    }
    
    /// 현재 포커스된 앱에 텍스트를 입력합니다
    /// - Parameters:
    ///   - text: 입력할 텍스트
    ///   - submitText: true이면 텍스트 입력 후 Enter 키를 전송
    /// - Returns: 성공 여부
    func inputTextToCurrentApp(_ text: String, submitText: Bool = false) async -> Bool {
        do {
            if submitText {
                try await TextInputAutomator.shared.inputTextAndSubmit(text)
            } else {
                try TextInputAutomator.shared.inputTextToFocusedApp(text)
            }
            
            #if DEBUG
            print("✅ Successfully input text to current app")
            #endif
            return true
        } catch {
            #if DEBUG
            print("❌ Failed to input text to current app: \(error)")
            #endif
            return false
        }
    }
    
    /// 현재 포커스된 앱의 텍스트를 실시간으로 교체합니다 (음성 인식 중)
    /// - Parameter text: 교체할 텍스트
    /// - Returns: 성공 여부
    func replaceTextInCurrentApp(_ text: String) -> Bool {
        do {
            try TextInputAutomator.shared.replaceCurrentText(text)
            return true
        } catch {
            #if DEBUG
            print("❌ Failed to replace text in current app: \(error)")
            #endif
            return false
        }
    }
}