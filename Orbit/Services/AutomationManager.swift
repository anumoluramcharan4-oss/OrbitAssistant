import Foundation
import ApplicationServices
import AppKit

class AutomationManager {
    static let shared = AutomationManager()
    
    private init() {}
    
    /// Checks if the application has Accessibility permission.
    func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    /// Checks if the application has permission to send Apple Events to target application.
    func checkAppleEventsPermission(forBundleId bundleId: String) -> Bool {
        let source = "tell application id \"\(bundleId)\" to get name"
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary? = nil
        script.executeAndReturnError(&error)
        if let err = error, let errNum = err[NSAppleScript.errorNumber] as? Int {
            if errNum == -1743 {
                return false
            }
        }
        return true
    }
    
    /// Opens the System Settings pane to Accessibility privacy controls.
    func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
