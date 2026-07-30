import Foundation
import AppKit

struct CommandRoutingResult {
    let responseText: String
    let commandToRegister: Command?
}

class CommandRouter {
    static let shared = CommandRouter()
    
    private init() {}
    
    func route(_ query: String) -> CommandRoutingResult {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        
        // 1. Handle Greetings
        if normalized == "hello" || normalized == "hi" {
            let cmd = Command(
                title: "Hi",
                description: "Greet the assistant",
                iconName: "hand.wave.fill",
                category: "Interaction"
            )
            return CommandRoutingResult(
                responseText: "Hello! I am Orbit, your native macOS assistant. How can I help you today?",
                commandToRegister: cmd
            )
        }
        
        // 2. Handle Time Queries
        if normalized == "what time is it" {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeString = formatter.string(from: Date())
            let response = "The current local time is \(timeString)."
            let cmd = Command(
                title: "What time is it",
                description: "Check local system time",
                iconName: "clock.fill",
                category: "System"
            )
            return CommandRoutingResult(responseText: response, commandToRegister: cmd)
        }
        
        // 3. Handle Date Queries
        if normalized == "what is today's date" || normalized == "what is todays date" {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            let dateString = formatter.string(from: Date())
            let response = "Today's date is \(dateString)."
            let cmd = Command(
                title: "What is today's date",
                description: "Check current calendar date",
                iconName: "calendar",
                category: "System"
            )
            return CommandRoutingResult(responseText: response, commandToRegister: cmd)
        }
        
        // 4. Handle Search Commands
        
        // A. "open safari and search [query]"
        if normalized.hasPrefix("open safari and search ") {
            let query = String(trimmed.dropFirst("open safari and search ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                MacActionService.shared.searchInBrowser(bundleId: "com.apple.Safari", query: query) { success, message in
                    if !success {
                        DispatchQueue.main.async {
                            ChatService.shared.messages.append(ChatMessage(text: message, sender: .assistant))
                        }
                    }
                }
                let cmd = Command(
                    title: "Search Safari: \(query)",
                    description: "Search Google using Safari browser",
                    iconName: "safari.fill",
                    category: "Productivity"
                )
                return CommandRoutingResult(responseText: "Opening Safari and searching for \"\(query)\".", commandToRegister: cmd)
            } else {
                return CommandRoutingResult(responseText: "Search query is empty.", commandToRegister: nil)
            }
        }
        
        // B. "open chrome and search [query]"
        if normalized.hasPrefix("open chrome and search ") {
            let query = String(trimmed.dropFirst("open chrome and search ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                if !MacActionService.shared.isAppInstalled(bundleId: "com.google.Chrome") {
                    return CommandRoutingResult(
                        responseText: "Google Chrome is not installed on this Mac.",
                        commandToRegister: nil
                    )
                }
                MacActionService.shared.searchInBrowser(bundleId: "com.google.Chrome", query: query) { success, message in
                    if !success {
                        DispatchQueue.main.async {
                            ChatService.shared.messages.append(ChatMessage(text: message, sender: .assistant))
                        }
                    }
                }
                let cmd = Command(
                    title: "Search Chrome: \(query)",
                    description: "Search Google using Google Chrome browser",
                    iconName: "globe",
                    category: "Productivity"
                )
                return CommandRoutingResult(responseText: "Opening Google Chrome and searching for \"\(query)\".", commandToRegister: cmd)
            } else {
                return CommandRoutingResult(responseText: "Search query is empty.", commandToRegister: nil)
            }
        }
        
        // C. "search amazon for [query]"
        if normalized.hasPrefix("search amazon for ") {
            let query = String(trimmed.dropFirst("search amazon for ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                MacActionService.shared.searchWebsite(urlTemplate: "https://www.amazon.com/s", query: query) { success, message in
                    if !success {
                        DispatchQueue.main.async {
                            ChatService.shared.messages.append(ChatMessage(text: message, sender: .assistant))
                        }
                    }
                }
                let cmd = Command(
                    title: "Amazon Search: \(query)",
                    description: "Search Amazon products results",
                    iconName: "magnifyingglass",
                    category: "Productivity"
                )
                return CommandRoutingResult(responseText: "Searching Amazon for \"\(query)\".", commandToRegister: cmd)
            } else {
                return CommandRoutingResult(responseText: "Search query is empty.", commandToRegister: nil)
            }
        }
        
        // D. "search youtube for [query]"
        if normalized.hasPrefix("search youtube for ") {
            let query = String(trimmed.dropFirst("search youtube for ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                MacActionService.shared.searchWebsite(urlTemplate: "https://www.youtube.com/results", query: query) { success, message in
                    if !success {
                        DispatchQueue.main.async {
                            ChatService.shared.messages.append(ChatMessage(text: message, sender: .assistant))
                        }
                    }
                }
                let cmd = Command(
                    title: "YouTube Search: \(query)",
                    description: "Search YouTube videos results",
                    iconName: "play.rectangle.fill",
                    category: "Productivity"
                )
                return CommandRoutingResult(responseText: "Searching YouTube for \"\(query)\".", commandToRegister: cmd)
            } else {
                return CommandRoutingResult(responseText: "Search query is empty.", commandToRegister: nil)
            }
        }
        
        // E. "search [app] for [query]" (for unsupported desktop apps)
        let unsupportedSearchApps = ["spotify", "notes", "calendar", "mail", "messages", "app store", "textedit", "finder"]
        for app in unsupportedSearchApps {
            if normalized.hasPrefix("search \(app) for ") {
                let appName: String
                switch app {
                case "spotify": appName = "Spotify"
                case "notes": appName = "Notes"
                case "calendar": appName = "Calendar"
                case "mail": appName = "Mail"
                case "messages": appName = "Messages"
                case "app store": appName = "App Store"
                case "textedit": appName = "TextEdit"
                case "finder": appName = "Finder"
                default: appName = app.capitalized
                }
                return CommandRoutingResult(
                    responseText: "I can open \(appName), but I cannot control its internal search yet. Try a web search instead.",
                    commandToRegister: nil
                )
            }
        }
        
        // F. "search for [query]"
        if normalized.hasPrefix("search for ") {
            let terms = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !terms.isEmpty {
                MacActionService.shared.searchGoogle(terms: terms) { success, message in
                    if !success {
                        DispatchQueue.main.async {
                            ChatService.shared.messages.append(ChatMessage(text: message, sender: .assistant))
                        }
                    }
                }
                let cmd = Command(
                    title: "Search: \(terms)",
                    description: "Search Google browser results",
                    iconName: "magnifyingglass",
                    category: "Productivity"
                )
                return CommandRoutingResult(responseText: "Searching Google for \"\(terms)\".", commandToRegister: cmd)
            } else {
                return CommandRoutingResult(responseText: "Google search query is empty.", commandToRegister: nil)
            }
        }
        
        // G. "search [query]"
        if normalized.hasPrefix("search ") {
            let terms = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !terms.isEmpty {
                MacActionService.shared.searchGoogle(terms: terms) { success, message in
                    if !success {
                        DispatchQueue.main.async {
                            ChatService.shared.messages.append(ChatMessage(text: message, sender: .assistant))
                        }
                    }
                }
                let cmd = Command(
                    title: "Search: \(terms)",
                    description: "Search Google browser results",
                    iconName: "magnifyingglass",
                    category: "Productivity"
                )
                return CommandRoutingResult(responseText: "Searching Google for \"\(terms)\".", commandToRegister: cmd)
            } else {
                return CommandRoutingResult(responseText: "Google search query is empty.", commandToRegister: nil)
            }
        }
        
        // 5. Handle "open [target]" commands
        if normalized.hasPrefix("open ") {
            let target = String(normalized.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            let originalTarget = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // A. Check allowlisted web addresses (google, youtube, github, gmail)
            let allowedWebsites = ["google", "youtube", "github", "gmail"]
            if allowedWebsites.contains(target) {
                MacActionService.shared.openWebsite(name: target) { _, _ in }
                let cmd = Command(
                    title: "Open \(originalTarget.capitalized)",
                    description: "Load \(originalTarget.capitalized) website",
                    iconName: target == "youtube" ? "play.rectangle.fill" : "safari.fill",
                    category: "Navigation"
                )
                return CommandRoutingResult(responseText: "Opening \(originalTarget.capitalized).", commandToRegister: cmd)
            }
            
            // B. Check allowlisted system folders (downloads, documents)
            if target == "downloads" || target == "documents" {
                MacActionService.shared.openFolder(type: target) { _, _ in }
                let cmd = Command(
                    title: "Open \(originalTarget.capitalized)",
                    description: "Open \(originalTarget.capitalized) folder",
                    iconName: "folder.fill",
                    category: "System"
                )
                return CommandRoutingResult(responseText: "Opening \(originalTarget.capitalized).", commandToRegister: cmd)
            }
            
            // C. Check allowlisted applications
            if MacActionService.shared.isAppSupported(name: target) {
                guard let appInfo = MacActionService.shared.getAppInfo(for: target) else {
                    return CommandRoutingResult(
                        responseText: "App '\(originalTarget)' is not in Orbit's safety allowlist. This action is not supported yet.",
                        commandToRegister: nil
                    )
                }
                
                // Verify that the application is installed before routing
                if !MacActionService.shared.isAppInstalled(bundleId: appInfo.bundleId) {
                    return CommandRoutingResult(
                        responseText: "\(appInfo.displayName) is not installed on this Mac.",
                        commandToRegister: nil
                    )
                }
                
                // Launch the app
                MacActionService.shared.launchApp(name: target) { success, message in
                    if !success {
                        // Append error message to chat messages list
                        DispatchQueue.main.async {
                            ChatService.shared.messages.append(ChatMessage(text: message, sender: .assistant))
                        }
                    }
                }
                
                let iconName: String
                switch target {
                case "safari": iconName = "safari.fill"
                case "finder": iconName = "macwindow.on.rectangle"
                case "calendar": iconName = "calendar"
                case "notes": iconName = "note.text"
                case "spotify": iconName = "music.note"
                case "mail": iconName = "envelope.fill"
                case "messages": iconName = "message.fill"
                case "app store": iconName = "bag.fill"
                case "textedit": iconName = "doc.text.fill"
                default: iconName = "app.badge.fill"
                }
                
                let cmd = Command(
                    title: "Open \(appInfo.displayName)",
                    description: "Launch \(appInfo.displayName) application",
                    iconName: iconName,
                    category: "System"
                )
                return CommandRoutingResult(responseText: "Opening and focusing \(appInfo.displayName).", commandToRegister: cmd)
            }
            
            // D. Handle non-allowlisted launch commands
            return CommandRoutingResult(
                responseText: "App '\(originalTarget)' is not in Orbit's safety allowlist. This action is not supported yet.",
                commandToRegister: nil
            )
        }
        
        // 6. Generic Fallback
        let response = "I don’t know how to do that yet, but I’m learning."
        return CommandRoutingResult(responseText: response, commandToRegister: nil)
    }
}
