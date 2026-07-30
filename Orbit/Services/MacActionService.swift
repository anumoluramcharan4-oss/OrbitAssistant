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
    
    struct AppInfo {
        let displayName: String
        let bundleId: String
    }
    
    // SAFETY DECISION: Allowed applications bundle identifiers.
    // Using bundle identifiers guarantees we query standard Launch Services.
    // This stops system injection of execution scripts or arbitrary shell applications.
    private let supportedApps: [String: AppInfo] = [
        "safari": AppInfo(displayName: "Safari", bundleId: "com.apple.Safari"),
        "finder": AppInfo(displayName: "Finder", bundleId: "com.apple.finder"),
        "notes": AppInfo(displayName: "Notes", bundleId: "com.apple.Notes"),
        "calendar": AppInfo(displayName: "Calendar", bundleId: "com.apple.iCal"),
        "google chrome": AppInfo(displayName: "Google Chrome", bundleId: "com.google.Chrome"),
        "chrome": AppInfo(displayName: "Google Chrome", bundleId: "com.google.Chrome"),
        "spotify": AppInfo(displayName: "Spotify", bundleId: "com.spotify.client"),
        "textedit": AppInfo(displayName: "TextEdit", bundleId: "com.apple.TextEdit"),
        "mail": AppInfo(displayName: "Mail", bundleId: "com.apple.mail"),
        "messages": AppInfo(displayName: "Messages", bundleId: "com.apple.MobileSMS"),
        "app store": AppInfo(displayName: "App Store", bundleId: "com.apple.AppStore")
    ]
    
    // Helper to get AppInfo from string key
    func getAppInfo(for name: String) -> AppInfo? {
        let cleanName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return supportedApps[cleanName]
    }
    
    // Helper to check if name is in allowlist
    func isAppSupported(name: String) -> Bool {
        let cleanName = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return supportedApps[cleanName] != nil
    }
    
    // Safety check function to verify if the bundle identifier is registered in launch services.
    func isAppInstalled(bundleId: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
    
    // Launches/focuses allowlisted application bundle identifier.
    func launchApp(name: String, completion: @escaping (Bool, String) -> Void) {
        guard let appInfo = getAppInfo(for: name) else {
            completion(false, "App '\(name)' is not in Orbit's safety allowlist. This action is not supported yet.")
            return
        }
        
        let bundleId = appInfo.bundleId
        let displayName = appInfo.displayName
        
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            completion(false, "\(displayName) is not installed on this Mac.")
            return
        }
        
        // If it is already running, bring it to the front using NSRunningApplication activation
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        if let runningApp = runningApps.first {
            let activated = runningApp.activate(options: [.activateIgnoringOtherApps])
            if activated {
                completion(true, "Opening and focusing \(displayName).")
                return
            }
        }
        
        // Open the application asynchronously via modern NSWorkspace.OpenConfiguration
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        DispatchQueue.main.async {
            NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                if let error = error {
                    let failMsg = "Failed to launch \(displayName): \(error.localizedDescription)"
                    print("Orbit Error: \(failMsg)")
                    completion(false, failMsg)
                } else {
                    completion(true, "Opening and focusing \(displayName).")
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
        
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: trimmed)]
        
        guard let url = components?.url else {
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
    
    // Search within a specific browser (Safari or Chrome) and activate it
    func searchInBrowser(bundleId: String, query: String, completion: @escaping (Bool, String) -> Void) {
        let displayName = bundleId == "com.apple.Safari" ? "Safari" : "Google Chrome"
        
        guard let browserAppURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            completion(false, "\(displayName) is not installed on this Mac.")
            return
        }
        
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        
        guard let searchURL = components?.url else {
            completion(false, "Invalid search query.")
            return
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        
        DispatchQueue.main.async {
            NSWorkspace.shared.open([searchURL], withApplicationAt: browserAppURL, configuration: config) { _, error in
                if let error = error {
                    let errorMsg = "Failed to search in \(displayName): \(error.localizedDescription)"
                    print("Orbit Error: \(errorMsg)")
                    completion(false, errorMsg)
                } else {
                    completion(true, "Opening \(displayName) and searching for \"\(query)\".")
                }
            }
        }
    }
    
    // Search on specific website (Amazon or YouTube)
    func searchWebsite(urlTemplate: String, query: String, completion: @escaping (Bool, String) -> Void) {
        let baseURL: String
        let queryParamName: String
        let serviceName: String
        
        if urlTemplate.contains("amazon.com") {
            baseURL = "https://www.amazon.com/s"
            queryParamName = "k"
            serviceName = "Amazon"
        } else if urlTemplate.contains("youtube.com") {
            baseURL = "https://www.youtube.com/results"
            queryParamName = "search_query"
            serviceName = "YouTube"
        } else {
            baseURL = "https://www.google.com/search"
            queryParamName = "q"
            serviceName = "Google"
        }
        
        var components = URLComponents(string: baseURL)
        components?.queryItems = [URLQueryItem(name: queryParamName, value: query)]
        
        guard let searchURL = components?.url else {
            completion(false, "Invalid search query.")
            return
        }
        
        DispatchQueue.main.async {
            if NSWorkspace.shared.open(searchURL) {
                completion(true, "Searching \(serviceName) for \"\(query)\".")
            } else {
                completion(false, "Failed to open search URL.")
            }
        }
    }
}
