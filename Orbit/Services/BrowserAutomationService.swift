import Foundation
import AppKit

class BrowserAutomationService {
    static let shared = BrowserAutomationService()
    
    private init() {}
    
    /// Opens the specified website URL in Safari (or default browser if Safari is not found).
    func openWebsite(_ url: URL, inBrowser browserName: String?, completion: @escaping (Bool, String) -> Void) {
        BrowserService.shared.openURL(url, inBrowser: browserName, completion: completion)
    }
    
    /// Navigates directly to the site-specific query page for allowlisted domains.
    func searchWebsite(site: String, query: String, inBrowser browserName: String?, completion: @escaping (Bool, String) -> Void) {
        let cleanSite = site.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let queryEncoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        let searchURLString: String
        if cleanSite.contains("amazon") {
            searchURLString = "https://www.amazon.com/s?k=\(queryEncoded)"
        } else if cleanSite.contains("youtube") {
            searchURLString = "https://www.youtube.com/results?search_query=\(queryEncoded)"
        } else if cleanSite.contains("github") {
            searchURLString = "https://github.com/search?q=\(queryEncoded)"
        } else {
            // Default to Google search
            searchURLString = "https://www.google.com/search?q=\(queryEncoded)"
        }
        
        guard let url = URL(string: searchURLString) else {
            completion(false, "Invalid search URL generated.")
            return
        }
        
        BrowserService.shared.openURL(url, inBrowser: browserName, completion: completion)
    }
}
