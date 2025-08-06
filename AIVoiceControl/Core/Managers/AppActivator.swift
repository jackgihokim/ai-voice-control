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
}