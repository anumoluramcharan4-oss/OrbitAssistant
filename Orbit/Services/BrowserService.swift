import Foundation
import AppKit

class BrowserService {
    static let shared = BrowserService()
    
    private init() {}
    
    // Allowed websites explicitly mentioned in the requirements
    private let allowedDomains = [
        "amazon.com",
        "google.com",
        "youtube.com",
        "github.com",
        "chat.openai.com",
        "docs.google.com"
    ]
    
    // Mapping of site keywords to their full canonical URLs
    private let siteMappings = [
        "amazon": "https://www.amazon.com",
        "google": "https://www.google.com",
        "youtube": "https://www.youtube.com",
        "github": "https://github.com",
        "chat.openai.com": "https://chat.openai.com",
        "docs.google.com": "https://docs.google.com"
    ]
    
    /// Normalizes and validates an input string into a safe, allowed HTTPS URL.
    /// Returns nil if the URL is not allowed.
    func validateAndNormalizeURL(_ input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = trimmed.lowercased()
        
        // 1. If it starts with https://, parse and validate it as a valid HTTPS URL
        if lowercase.hasPrefix("https://") {
            if let url = URL(string: trimmed), url.host != nil {
                return url
            }
            return nil
        }
        
        // 2. Reject non-HTTPS urls
        if lowercase.hasPrefix("http://") {
            return nil
        }
        
        // 3. Match exact domains/keys first to avoid containment match (e.g. docs.google.com matching google keyword)
        if let canonicalURL = siteMappings[lowercase] {
            return URL(string: canonicalURL)
        }
        
        if allowedDomains.contains(lowercase) {
            return URL(string: "https://\(lowercase)")
        }
        
        // 4. Match common keywords exactly or with suffix
        let commonKeywords = ["amazon", "google", "youtube", "github"]
        for kw in commonKeywords {
            if lowercase == kw || lowercase == "\(kw).com" {
                if let canonical = siteMappings[kw] {
                    return URL(string: canonical)
                }
            }
        }
        
        // 5. Match contains check for common keywords (fallback)
        for kw in commonKeywords {
            if lowercase.contains(kw) {
                if let canonical = siteMappings[kw] {
                    return URL(string: canonical)
                }
            }
        }
        
        return nil
    }
    
    private let browserBundleIds = [
        "safari": "com.apple.Safari",
        "chrome": "com.google.Chrome",
        "google chrome": "com.google.Chrome",
        "brave": "com.brave.Browser",
        "arc": "company.thebrowser.Browser"
    ]
    
    /// Checks if Safari is currently running.
    func isSafariRunning() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari")
        return !runningApps.isEmpty
    }
    
    /// Opens the URL in the specified browser or default browser.
    /// Reuses running instance if possible.
    func openURL(_ url: URL, inBrowser browserName: String?, completion: @escaping (Bool, String) -> Void) {
        var targetBundleId = "com.apple.Safari"
        var browserDisplayName = "Safari"
        
        if let name = browserName {
            let cleanName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if let bundleId = browserBundleIds[cleanName] {
                targetBundleId = bundleId
                browserDisplayName = name
            } else {
                completion(false, "Browser '\(name)' is not allowed. Only allowed browsers are Safari, Chrome, Brave, and Arc.")
                return
            }
        }
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: targetBundleId) else {
            // Fallback to default browser open if target browser urlForApplication fails
            DispatchQueue.main.async {
                if NSWorkspace.shared.open(url) {
                    completion(true, "\(browserDisplayName) not found; opened in Default Browser.")
                } else {
                    completion(false, "Failed to open \(url.absoluteString) in Default Browser.")
                }
            }
            return
        }
        
        // Bring browser to front if it is already running
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleId)
        if let runningBrowser = runningApps.first {
            _ = runningBrowser.activate(options: [.activateIgnoringOtherApps])
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        DispatchQueue.main.async {
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: config) { _, error in
                if let error = error {
                    let msg = "Failed to open URL in \(browserDisplayName): \(error.localizedDescription)"
                    print("Orbit Error: \(msg)")
                    completion(false, msg)
                } else {
                    completion(true, "Opening \(url.absoluteString) in \(browserDisplayName).")
                }
            }
        }
    }
    
    /// Opens a Google Search in the default browser.
    func searchGoogle(query: String, completion: @escaping (Bool, String) -> Void) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(false, "Search query is empty.")
            return
        }
        
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        
        guard let searchURL = components?.url else {
            completion(false, "Invalid search URL generated.")
            return
        }
        
        DispatchQueue.main.async {
            if NSWorkspace.shared.open(searchURL) {
                completion(true, "Searching Google for \"\(trimmed)\".")
            } else {
                completion(false, "Failed to load Google search page.")
            }
        }
    }
}
