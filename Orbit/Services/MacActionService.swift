import Foundation
import AppKit

class MacActionService {
    static let shared = MacActionService()
    
    private init() {}
    
    // SAFETY DECISION: Allowed website URLs are static. We map input keys strictly to these addresses.
    // This prevents launching malicious URLs or local file links (file://) in the browser.
    private let allowedWebsites = [
        "google": "https://www.google.com",
        "youtube": "https://www.youtube.com",
        "github": "https://www.github.com",
        "gmail": "https://mail.google.com"
    ]
    
    // SAFETY DECISION: Allowed applications bundle identifiers.
    // Using bundle identifiers guarantees we query standard Launch Services.
    // This stops system injection of execution scripts or arbitrary shell applications.
    private let allowedApps = [
        "safari": "com.apple.Safari",
        "chrome": "com.google.Chrome",
        "notes": "com.apple.Notes",
        "calendar": "com.apple.iCal",
        "spotify": "com.spotify.client"
    ]
    
    // Safety check function to verify if the bundle identifier is registered in launch services.
    func isAppInstalled(bundleId: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
    
    // Launches allowlisted application bundle identifier.
    func launchApp(name: String, completion: @escaping (Bool, String) -> Void) {
        let cleanName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let bundleId = allowedApps[cleanName] else {
            completion(false, "App '\(name)' is not in Orbit's safety allowlist. This action is not supported yet.")
            return
        }
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            let errorMsg = cleanName == "chrome" ? "Google Chrome is not installed on this system." :
                           cleanName == "spotify" ? "Spotify is not installed on this system." :
                           "\(name.capitalized) is not installed."
            completion(false, errorMsg)
            return
        }
        
        // Open the application asynchronously via modern NSWorkspace.OpenConfiguration
        let config = NSWorkspace.OpenConfiguration()
        DispatchQueue.main.async {
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                if let error = error {
                    completion(false, "Failed to launch \(name.capitalized): \(error.localizedDescription)")
                } else {
                    completion(true, "Opening \(name.capitalized).")
                }
            }
        }
    }
    
    // SAFETY DECISION: Only open standard document directories mapped via Sandbox API.
    // We restrict opening directories to safe user-space paths, blocking direct access to system cores or caches.
    func openFolder(type: String, completion: @escaping (Bool, String) -> Void) {
        let cleanType = type.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var folderURL: URL? = nil
        var folderLabel = ""
        
        if cleanType == "downloads" {
            folderURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            folderLabel = "Downloads"
        } else if cleanType == "documents" {
            folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            folderLabel = "Documents"
        }
        
        guard let url = folderURL else {
            completion(false, "Folder '\(type)' is not in Orbit's safety allowlist. This action is not supported yet.")
            return
        }
        
        DispatchQueue.main.async {
            if NSWorkspace.shared.open(url) {
                completion(true, "Opening \(folderLabel).")
            } else {
                completion(false, "Failed to open \(folderLabel) folder.")
            }
        }
    }
    
    // Mapped website key lookup.
    func openWebsite(name: String, completion: @escaping (Bool, String) -> Void) {
        let cleanName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let urlString = allowedWebsites[cleanName], let url = URL(string: urlString) else {
            completion(false, "Website '\(name)' is not in Orbit's safety allowlist. This action is not supported yet.")
            return
        }
        
        DispatchQueue.main.async {
            if NSWorkspace.shared.open(url) {
                completion(true, "Opening \(name.capitalized).")
            } else {
                completion(false, "Failed to load website: \(urlString)")
            }
        }
    }
    
    // SAFETY DECISION: Search terms are url-encoded to prevent URL injection attacks.
    // The query is strictly passed to google.com/search in default system browser.
    func searchGoogle(terms: String, completion: @escaping (Bool, String) -> Void) {
        let trimmed = terms.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(false, "Search query is empty.")
            return
        }
        
        guard let encodedTerms = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(false, "Could not encode search query terms safely.")
            return
        }
        
        let searchURLString = "https://www.google.com/search?q=\(encodedTerms)"
        guard let url = URL(string: searchURLString) else {
            completion(false, "Invalid search URL generated.")
            return
        }
        
        DispatchQueue.main.async {
            if NSWorkspace.shared.open(url) {
                completion(true, "Searching Google for \"\(trimmed)\".")
            } else {
                completion(false, "Failed to load Google search page.")
            }
        }
    }
}
