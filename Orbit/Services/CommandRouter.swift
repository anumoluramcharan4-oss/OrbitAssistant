import Foundation
import AppKit

struct CommandRoutingResult {
    let responseText: String
    let commandToRegister: Command?
    var isFileConfirmation: Bool = false
    var isSleepConfirmation: Bool = false
    var filePath: String? = nil
    var tasks: [Task]? = nil
}

class CommandRouter {
    static let shared = CommandRouter()
    
    private init() {}
    
    private func isPathInStandardDirectories(_ path: String) -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        let canonicalPath = URL(fileURLWithPath: expandedPath).path
        
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path,
           canonicalPath.hasPrefix(docs) {
            return true
        }
        if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path,
           canonicalPath.hasPrefix(downloads) {
            return true
        }
        return false
    }
    
    func route(_ query: String) -> CommandRoutingResult {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle basic queries
        let isGreeting = normalized.contains("hello") || normalized.contains("hi ") || normalized == "hi" || normalized.contains("hey ") || normalized == "hey" || normalized.contains("greetings")
        let isTime = normalized.contains("time")
        let isDate = (normalized.contains("date") || normalized.contains("today") || normalized.contains("calendar")) && !normalized.contains("open")
        
        if isGreeting {
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
        } else if isTime {
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
        } else if isDate {
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
        
        // Generate plan
        let tasks = TaskPlanner.shared.plan(query: query)
        
        guard !tasks.isEmpty else {
            let response = "I don’t know how to do that yet, but I’m learning."
            return CommandRoutingResult(responseText: response, commandToRegister: nil)
        }
        
        // Check for sleep confirmation
        for task in tasks {
            if task.action == .sleepMac {
                return CommandRoutingResult(
                    responseText: "Sleeping the Mac requires confirmation.",
                    commandToRegister: nil,
                    isSleepConfirmation: true,
                    tasks: tasks
                )
            }
        }
        
        // Check for file confirmation
        for task in tasks {
            if task.action == .openFile, let filePath = task.file {
                let expandedPath = (filePath as NSString).expandingTildeInPath
                let canonicalPath = URL(fileURLWithPath: expandedPath).path
                
                if !FileManager.default.fileExists(atPath: canonicalPath) {
                    return CommandRoutingResult(
                        responseText: "File not found at: \(filePath)",
                        commandToRegister: nil
                    )
                }
                
                if !isPathInStandardDirectories(canonicalPath) {
                    return CommandRoutingResult(
                        responseText: "Opening \(URL(fileURLWithPath: canonicalPath).lastPathComponent) requires confirmation.",
                        commandToRegister: nil,
                        isFileConfirmation: true,
                        filePath: canonicalPath,
                        tasks: tasks
                    )
                }
            }
        }
        
        // Single task backwards compatibility and clean responses
        if tasks.count == 1 {
            let task = tasks[0]
            switch task.action {
            case .launchApp:
                guard let target = task.targetApp, let appInfo = ApplicationService.shared.getAppInfo(for: target) else {
                    let cleanApp = task.targetApp ?? query
                    return CommandRoutingResult(
                        responseText: "App '\(cleanApp)' is not in Orbit's safety allowlist. This action is not supported yet.",
                        commandToRegister: nil
                    )
                }
                if !ApplicationService.shared.isAppInstalled(bundleId: appInfo.bundleId) {
                    return CommandRoutingResult(
                        responseText: "\(appInfo.displayName) is not installed on this Mac.",
                        commandToRegister: nil
                    )
                }
                let iconName: String
                switch target {
                case "safari": iconName = "safari.fill"
                case "finder": iconName = "macwindow.on.rectangle"
                case "notes": iconName = "note.text"
                case "textedit": iconName = "doc.text.fill"
                case "terminal": iconName = "terminal.fill"
                case "vscode", "vs code", "visual studio code": iconName = "curlybracket"
                case "calculator": iconName = "plus.slash.minus"
                case "system settings", "settings": iconName = "gearshape.fill"
                default: iconName = "app.badge.fill"
                }
                let cmd = Command(
                    title: "Open \(appInfo.displayName)",
                    description: "Launch \(appInfo.displayName) application",
                    iconName: iconName,
                    category: "System"
                )
                return CommandRoutingResult(
                    responseText: "Opening and focusing \(appInfo.displayName).",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .closeApp:
                guard let target = task.targetApp, let appInfo = ApplicationService.shared.getAppInfo(for: target) else {
                    let cleanApp = task.targetApp ?? query
                    return CommandRoutingResult(
                        responseText: "App '\(cleanApp)' is not in Orbit's safety allowlist. This action is not supported yet.",
                        commandToRegister: nil
                    )
                }
                let cmd = Command(
                    title: "Close \(appInfo.displayName)",
                    description: "Terminate \(appInfo.displayName) application",
                    iconName: "xmark.circle.fill",
                    category: "System"
                )
                return CommandRoutingResult(
                    responseText: "Closing \(appInfo.displayName).",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .forceQuitApp:
                guard let target = task.targetApp, let appInfo = ApplicationService.shared.getAppInfo(for: target) else {
                    let cleanApp = task.targetApp ?? query
                    return CommandRoutingResult(
                        responseText: "App '\(cleanApp)' is not in Orbit's safety allowlist. This action is not supported yet.",
                        commandToRegister: nil
                    )
                }
                let cmd = Command(
                    title: "Force Quit \(appInfo.displayName)",
                    description: "Force close \(appInfo.displayName) application",
                    iconName: "xmark.circle.fill",
                    category: "System"
                )
                return CommandRoutingResult(
                    responseText: "Force closing \(appInfo.displayName).",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .hideApp:
                guard let target = task.targetApp, let appInfo = ApplicationService.shared.getAppInfo(for: target) else {
                    let cleanApp = task.targetApp ?? query
                    return CommandRoutingResult(
                        responseText: "App '\(cleanApp)' is not in Orbit's safety allowlist. This action is not supported yet.",
                        commandToRegister: nil
                    )
                }
                let cmd = Command(
                    title: "Hide \(appInfo.displayName)",
                    description: "Hide \(appInfo.displayName) application",
                    iconName: "eye.slash.fill",
                    category: "System"
                )
                return CommandRoutingResult(
                    responseText: "Hiding \(appInfo.displayName).",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .activateApp:
                guard let target = task.targetApp, let appInfo = ApplicationService.shared.getAppInfo(for: target) else {
                    let cleanApp = task.targetApp ?? query
                    return CommandRoutingResult(
                        responseText: "App '\(cleanApp)' is not in Orbit's safety allowlist. This action is not supported yet.",
                        commandToRegister: nil
                    )
                }
                let cmd = Command(
                    title: "Activate \(appInfo.displayName)",
                    description: "Bring \(appInfo.displayName) to front",
                    iconName: "arrow.up.and.person.rectangle.portrait",
                    category: "System"
                )
                return CommandRoutingResult(
                    responseText: "Activating \(appInfo.displayName).",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .openFolder:
                guard let folderName = task.folder else {
                    return CommandRoutingResult(responseText: "Folder not specified.", commandToRegister: nil)
                }
                let cmd = Command(
                    title: "Open \(folderName.capitalized)",
                    description: "Open \(folderName.capitalized) folder",
                    iconName: "folder.fill",
                    category: "System"
                )
                return CommandRoutingResult(
                    responseText: "Opening \(folderName.capitalized).",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .openFile:
                guard let rawPath = task.file else {
                    return CommandRoutingResult(responseText: "File path not specified.", commandToRegister: nil)
                }
                let expandedPath = (rawPath as NSString).expandingTildeInPath
                let canonicalPath = URL(fileURLWithPath: expandedPath).path
                let fileName = URL(fileURLWithPath: canonicalPath).lastPathComponent
                let cmd = Command(
                    title: "Open \(fileName)",
                    description: "Open local file",
                    iconName: "doc.text.fill",
                    category: "Files"
                )
                return CommandRoutingResult(
                    responseText: "Opening file \(fileName).",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .revealFile:
                guard let rawPath = task.file else {
                    return CommandRoutingResult(responseText: "File path not specified.", commandToRegister: nil)
                }
                let expandedPath = (rawPath as NSString).expandingTildeInPath
                let canonicalPath = URL(fileURLWithPath: expandedPath).path
                let fileName = URL(fileURLWithPath: canonicalPath).lastPathComponent
                let cmd = Command(
                    title: "Reveal \(fileName)",
                    description: "Reveal file in Finder",
                    iconName: "magnifyingglass",
                    category: "System"
                )
                return CommandRoutingResult(
                    responseText: "Revealing \(fileName) in Finder.",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .openWebsite:
                guard let urlString = task.website, let url = URL(string: urlString) else {
                    return CommandRoutingResult(responseText: "Invalid or unsupported website URL.", commandToRegister: nil)
                }
                let displayHost = url.host ?? "website"
                let cmd = Command(
                    title: "Open \(displayHost)",
                    description: "Load \(displayHost) in browser",
                    iconName: "safari.fill",
                    category: "Navigation"
                )
                return CommandRoutingResult(
                    responseText: "Opening \(displayHost) in browser.",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .searchWebsite:
                let queryText = task.searchQuery ?? ""
                guard !queryText.isEmpty else {
                    return CommandRoutingResult(responseText: "Search query is empty.", commandToRegister: nil)
                }
                let displaySite = task.website?.capitalized ?? "Google"
                let cmd = Command(
                    title: "Search: \(queryText)",
                    description: "Search \(displaySite) browser results",
                    iconName: "magnifyingglass",
                    category: "Productivity"
                )
                return CommandRoutingResult(
                    responseText: "Searching \(displaySite) for \"\(queryText)\".",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .openSystemSettings:
                let cmd = Command(
                    title: "Open System Settings",
                    description: "Launch System Settings application",
                    iconName: "gearshape.fill",
                    category: "System"
                )
                return CommandRoutingResult(
                    responseText: "Opening System Settings.",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .lockScreen:
                let cmd = Command(
                    title: "Lock Screen",
                    description: "Lock local macOS screen saver",
                    iconName: "lock.fill",
                    category: "System"
                )
                return CommandRoutingResult(
                    responseText: "Locking the screen.",
                    commandToRegister: cmd,
                    tasks: tasks
                )
                
            case .sleepMac:
                // Handled above via confirmation short-circuit
                break
            }
        }
        
        // Multi-step task sequence response
        let planDescription = tasks.enumerated().map { "\($0 + 1). \(ActionExecutor.shared.getActionDescription($1))" }.joined(separator: "\n")
        let responseText = "I have planned the following actions:\n\(planDescription)"
        let cmd = Command(
            title: query,
            description: "Multi-step command sequence",
            iconName: "list.bullet",
            category: "Automation"
        )
        
        return CommandRoutingResult(
            responseText: responseText,
            commandToRegister: cmd,
            tasks: tasks
        )
    }
}
