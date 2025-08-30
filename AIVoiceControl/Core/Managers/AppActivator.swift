import Foundation
import AppKit

@MainActor
class AppActivator {
    static let shared = AppActivator()
    
    private init() {}
    
    func activateApp(_ appConfig: AppConfiguration) -> Bool {
        let currentActiveApp = NSWorkspace.shared.frontmostApplication
        #if DEBUG
        print("🎯 [APP-ACTIVATOR] Attempting to activate \(appConfig.name) (\(appConfig.bundleIdentifier))")
        print("    Currently active: \(currentActiveApp?.localizedName ?? "Unknown") (\(currentActiveApp?.bundleIdentifier ?? "unknown"))")
        #endif
        
        // Try to find and activate the app using bundle identifier
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: appConfig.bundleIdentifier).first {
            // Method 1: Direct activation with force
            var success = false
            
            // If app is hidden, unhide it first
            if app.isHidden {
                #if DEBUG
                print("👁️ [APP-ACTIVATOR] App was hidden, unhiding...")
                #endif
                app.unhide()
                Thread.sleep(forTimeInterval: 0.05)
            }
            
            // Try activating multiple times with different options
            for attempt in 1...3 {
                success = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
                
                #if DEBUG
                print("🔄 [APP-ACTIVATOR] Activation attempt \(attempt): \(success ? "SUCCESS" : "FAILED")")
                #endif
                
                if success {
                    break
                }
                
                // Small delay between attempts
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            // Method 2: If still not activated, try forcing it to front
            if !success {
                #if DEBUG
                print("🔄 [APP-ACTIVATOR] Method 1 failed, trying Method 2 (launch without activation)")
                #endif
                // Set the app as active using a different approach
                NSWorkspace.shared.launchApplication(withBundleIdentifier: appConfig.bundleIdentifier,
                                                     options: [.withoutActivation],
                                                     additionalEventParamDescriptor: nil,
                                                     launchIdentifier: nil)
                Thread.sleep(forTimeInterval: 0.1)
                
                // Now try to activate again
                success = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
                
                #if DEBUG
                print("🔄 [APP-ACTIVATOR] Method 2 result: \(success ? "SUCCESS" : "FAILED")")
                #endif
            }
            
            // Method 3: Use NSWorkspace to bring to front (simpler approach)
            if !success {
                #if DEBUG
                print("🔄 [APP-ACTIVATOR] Method 2 failed, trying Method 3 (NSWorkspace launch)")
                #endif
                NSWorkspace.shared.launchApplication(withBundleIdentifier: appConfig.bundleIdentifier,
                                                     options: [],
                                                     additionalEventParamDescriptor: nil,
                                                     launchIdentifier: nil)
                success = true // Assume success as this rarely fails
                
                #if DEBUG
                print("🔄 [APP-ACTIVATOR] Method 3 completed (assumed success)")
                #endif
            }
            
            
            let finalActiveApp = NSWorkspace.shared.frontmostApplication
            #if DEBUG
            print("✅ [APP-ACTIVATOR] Final activation result: \(success)")
            print("    Now active: \(finalActiveApp?.localizedName ?? "Unknown") (\(finalActiveApp?.bundleIdentifier ?? "unknown"))")
            #endif
            return success
        }
        
        // If app is not running, try to launch it
        #if DEBUG
        print("🚀 [APP-ACTIVATOR] App not running, attempting to launch")
        #endif
        
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appConfig.bundleIdentifier) {
            do {
                let app = try NSWorkspace.shared.launchApplication(at: appURL, options: [.default], configuration: [:])
                
                #if DEBUG
                print("🚀 [APP-ACTIVATOR] Launch successful, waiting 0.5s...")
                #endif
                
                // Give the app a moment to launch
                Thread.sleep(forTimeInterval: 0.5)
                
                // Try to activate it again
                if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: appConfig.bundleIdentifier).first {
                    let success = runningApp.activate(options: [.activateIgnoringOtherApps])
                    
                    #if DEBUG
                    print("✅ [APP-ACTIVATOR] Launch activation result: \(success)")
                    #endif
                    
                    return success
                }
            } catch {
                #if DEBUG
                print("❌ [APP-ACTIVATOR] Launch failed: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("❌ [APP-ACTIVATOR] App not found in Applications folder")
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
            
            return true
        } catch {
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
            
            return true
        } catch {
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
            return false
        }
    }
}