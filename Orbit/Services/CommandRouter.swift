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
        
        // 4. Handle "search for [terms]"
        if normalized.hasPrefix("search for ") {
            let terms = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !terms.isEmpty {
                // Trigger Google search query in background
                MacActionService.shared.searchGoogle(terms: terms) { _, _ in }
                let response = "Searching Google for \"\(terms)\"."
                let cmd = Command(
                    title: "Search: \(terms)",
                    description: "Search Google browser results",
                    iconName: "magnifyingglass",
                    category: "Productivity"
                )
                return CommandRoutingResult(responseText: response, commandToRegister: cmd)
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
