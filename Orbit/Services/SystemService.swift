import Foundation
import AppKit

class SystemService {
    static let shared = SystemService()
    
    private init() {}
    
    func openSystemSettings(completion: @escaping (Bool, String) -> Void) {
        let url = URL(string: "x-apple.systempreferences:")!
        DispatchQueue.main.async {
            if NSWorkspace.shared.open(url) {
                completion(true, "Opened System Settings.")
            } else {
                completion(false, "Failed to open System Settings.")
            }
        }
    }
    
    func lockScreen(completion: @escaping (Bool, String) -> Void) {
        let lockScreenAppPath = "/System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app"
        let url = URL(fileURLWithPath: lockScreenAppPath)
        
        DispatchQueue.main.async {
            if NSWorkspace.shared.open(url) {
                completion(true, "Locked the screen.")
            } else {
                completion(false, "Failed to lock screen.")
            }
        }
    }
    
    func sleepMac(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.main.async {
            let script = NSAppleScript(source: "tell application \"Finder\" to sleep")
            var error: NSDictionary? = nil
            if let script = script {
                script.executeAndReturnError(&error)
                if let error = error {
                    completion(false, "Failed to sleep Mac: \(error)")
                } else {
                    completion(true, "Sleeping Mac.")
                }
            } else {
                completion(false, "Failed to create sleep script.")
            }
        }
    }
}
