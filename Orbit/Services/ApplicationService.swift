import Foundation
import AppKit

enum QuitState: String, Codable {
    case success
    case alreadyClosed
    case pendingForceQuitConfirmation
    case failure
}

class ApplicationService {
    static let shared = ApplicationService()
    
    private init() {}
    
    struct AppInfo {
        let displayName: String
        let bundleId: String
    }
    
    let supportedApps: [String: AppInfo] = [
        "safari": AppInfo(displayName: "Safari", bundleId: "com.apple.Safari"),
        "finder": AppInfo(displayName: "Finder", bundleId: "com.apple.finder"),
        "notes": AppInfo(displayName: "Notes", bundleId: "com.apple.Notes"),
        "textedit": AppInfo(displayName: "TextEdit", bundleId: "com.apple.TextEdit"),
        "terminal": AppInfo(displayName: "Terminal", bundleId: "com.apple.Terminal"),
        "vs code": AppInfo(displayName: "Visual Studio Code", bundleId: "com.microsoft.VSCode"),
        "vscode": AppInfo(displayName: "Visual Studio Code", bundleId: "com.microsoft.VSCode"),
        "visual studio code": AppInfo(displayName: "Visual Studio Code", bundleId: "com.microsoft.VSCode"),
        "calculator": AppInfo(displayName: "Calculator", bundleId: "com.apple.calculator"),
        "system settings": AppInfo(displayName: "System Settings", bundleId: "com.apple.systempreferences"),
        "system preferences": AppInfo(displayName: "System Settings", bundleId: "com.apple.systempreferences"),
        "settings": AppInfo(displayName: "System Settings", bundleId: "com.apple.systempreferences"),
        "google chrome": AppInfo(displayName: "Google Chrome", bundleId: "com.google.Chrome"),
        "chrome": AppInfo(displayName: "Google Chrome", bundleId: "com.google.Chrome"),
        "brave": AppInfo(displayName: "Brave", bundleId: "com.brave.Browser"),
        "arc": AppInfo(displayName: "Arc", bundleId: "company.thebrowser.Browser"),
        "mail": AppInfo(displayName: "Mail", bundleId: "com.apple.mail"),
        "calendar": AppInfo(displayName: "Calendar", bundleId: "com.apple.iCal"),
        "spotify": AppInfo(displayName: "Spotify", bundleId: "com.spotify.client")
    ]
    
    func getAppInfo(for name: String) -> AppInfo? {
        let clean = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return supportedApps[clean]
    }
    
    func isAppInstalled(bundleId: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
    
    func launchApp(name: String, completion: @escaping (Bool, String) -> Void) {
        guard let appInfo = getAppInfo(for: name) else {
            completion(false, "App '\(name)' is not in Orbit's safety allowlist.")
            return
        }
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appInfo.bundleId) else {
            completion(false, "\(appInfo.displayName) is not installed on this Mac.")
            return
        }
        
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: appInfo.bundleId)
        if let running = runningApps.first {
            if running.activate(options: [.activateIgnoringOtherApps]) {
                completion(true, "Opening and focusing \(appInfo.displayName).")
                return
            }
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        DispatchQueue.main.async {
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                if let error = error {
                    completion(false, "Failed to launch \(appInfo.displayName): \(error.localizedDescription)")
                } else {
                    completion(true, "Opening and focusing \(appInfo.displayName).")
                }
            }
        }
    }
    
    func quitApp(name: String, completion: @escaping (QuitState, String) -> Void) {
        guard let appInfo = getAppInfo(for: name) else {
            completion(.failure, "App '\(name)' is not in Orbit's safety allowlist.")
            return
        }
        
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: appInfo.bundleId)
        let mainApps = runningApps.filter { $0.activationPolicy == .regular }
        
        guard !mainApps.isEmpty else {
            completion(.alreadyClosed, "\(appInfo.displayName) is not currently running.")
            return
        }
        
        for app in mainApps {
            app.terminate()
        }
        
        // Wait 3.0 seconds to check if they closed
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let stillRunning = NSRunningApplication.runningApplications(withBundleIdentifier: appInfo.bundleId)
            let stillRunningMain = stillRunning.filter { $0.activationPolicy == .regular }
            if !stillRunningMain.isEmpty {
                completion(.pendingForceQuitConfirmation, "Some instances of \(appInfo.displayName) failed to quit. Do you want to force quit?")
            } else {
                completion(.success, "Closed \(appInfo.displayName).")
            }
        }
    }
    
    func forceQuitApp(name: String, completion: @escaping (Bool, String) -> Void) {
        guard let appInfo = getAppInfo(for: name) else {
            completion(false, "App '\(name)' is not in Orbit's safety allowlist.")
            return
        }
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: appInfo.bundleId)
        for app in runningApps {
            app.forceTerminate()
        }
        completion(true, "Force closed \(appInfo.displayName).")
    }
    
    func hideApp(name: String, completion: @escaping (Bool, String) -> Void) {
        guard let appInfo = getAppInfo(for: name) else {
            completion(false, "App '\(name)' is not in Orbit's safety allowlist.")
            return
        }
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: appInfo.bundleId)
        guard !runningApps.isEmpty else {
            completion(false, "\(appInfo.displayName) is not running.")
            return
        }
        for app in runningApps {
            app.hide()
        }
        completion(true, "Hid \(appInfo.displayName).")
    }
    
    func activateApp(name: String, completion: @escaping (Bool, String) -> Void) {
        launchApp(name: name, completion: completion)
    }
}
