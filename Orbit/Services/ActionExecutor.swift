import Foundation
import AppKit

class ActionExecutor {
    static let shared = ActionExecutor()
    
    private init() {}
    
    func getActionDescription(_ task: Task) -> String {
        switch task.action {
        case .launchApp:
            if let target = task.targetApp, let info = ApplicationService.shared.getAppInfo(for: target) {
                return "Launching \(info.displayName)..."
            }
            return "Launching application..."
        case .closeApp:
            if let target = task.targetApp, let info = ApplicationService.shared.getAppInfo(for: target) {
                return "Closing \(info.displayName)..."
            }
            return "Closing application..."
        case .forceQuitApp:
            if let target = task.targetApp, let info = ApplicationService.shared.getAppInfo(for: target) {
                return "Force closing \(info.displayName)..."
            }
            return "Force quitting application..."
        case .hideApp:
            if let target = task.targetApp, let info = ApplicationService.shared.getAppInfo(for: target) {
                return "Hiding \(info.displayName)..."
            }
            return "Hiding application..."
        case .activateApp:
            if let target = task.targetApp, let info = ApplicationService.shared.getAppInfo(for: target) {
                return "Activating \(info.displayName)..."
            }
            return "Activating application..."
        case .openFolder:
            return "Opening \(task.folder?.capitalized ?? "Folder")..."
        case .openFile:
            if let filePath = task.file {
                let name = URL(fileURLWithPath: filePath).lastPathComponent
                return "Opening file \(name)..."
            }
            return "Opening local file..."
        case .revealFile:
            if let filePath = task.file {
                let name = URL(fileURLWithPath: filePath).lastPathComponent
                return "Revealing file \(name) in Finder..."
            }
            return "Revealing file in Finder..."
        case .openWebsite:
            if let web = task.website, let url = URL(string: web) {
                return "Opening \(url.host ?? "website")..."
            }
            return "Opening website..."
        case .searchWebsite:
            let site = task.website ?? "Google"
            let query = task.searchQuery ?? ""
            return "Searching \(site.capitalized) for \"\(query)\"..."
        case .openSystemSettings:
            return "Opening System Settings..."
        case .lockScreen:
            return "Locking screen..."
        case .sleepMac:
            return "Sleeping Mac..."
        }
    }
    
    func execute(_ tasks: [Task], completion: @escaping (Bool, String, Bool) -> Void) {
        func runTaskIndex(_ index: Int) {
            guard index < tasks.count else {
                completion(true, "Successfully executed all actions.", true)
                return
            }
            
            let task = tasks[index]
            let description = getActionDescription(task)
            
            DispatchQueue.main.async {
                ChatService.shared.statusLabel = "Step \(index + 1)/\(tasks.count): \(description)"
            }
            
            executeSingleAction(task) { success, message, shouldShow in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        runTaskIndex(index + 1)
                    }
                } else {
                    completion(false, message, shouldShow)
                }
            }
        }
        
        runTaskIndex(0)
    }
    
    private func executeSingleAction(_ task: Task, completion: @escaping (Bool, String, Bool) -> Void) {
        // Permissions checks
        if task.action == .hideApp || task.action == .closeApp || task.action == .forceQuitApp {
            if !AutomationManager.shared.checkAccessibilityPermission() {
                DispatchQueue.main.async {
                    ChatService.shared.statusLabel = "Accessibility permission needed"
                    let msg = ChatMessage(
                        text: "Orbit needs Accessibility permission to control this application.",
                        sender: .assistant,
                        isAccessibilitySettingsCard: true
                    )
                    ChatService.shared.messages.append(msg)
                }
                completion(false, "Accessibility permission is required.", false)
                return
            }
        }
        
        switch task.action {
        case .launchApp:
            guard let app = task.targetApp else {
                completion(false, "No target application specified.", true)
                return
            }
            ApplicationService.shared.launchApp(name: app) { success, msg in
                completion(success, msg, true)
            }
            
        case .closeApp:
            guard let app = task.targetApp else {
                completion(false, "No target application specified.", true)
                return
            }
            ApplicationService.shared.quitApp(name: app) { state, msg in
                switch state {
                case .success, .alreadyClosed:
                    completion(true, msg, true)
                case .pendingForceQuitConfirmation:
                    DispatchQueue.main.async {
                        ChatService.shared.statusLabel = "Waiting for force quit..."
                        let msgObj = ChatMessage(
                            text: msg,
                            sender: .assistant,
                            isForceQuitConfirmation: true,
                            forceQuitAppName: app
                        )
                        ChatService.shared.messages.append(msgObj)
                    }
                    completion(false, msg, false)
                case .failure:
                    completion(false, msg, true)
                }
            }
            
        case .forceQuitApp:
            guard let app = task.targetApp else {
                completion(false, "No target application specified.", true)
                return
            }
            ApplicationService.shared.forceQuitApp(name: app) { success, msg in
                completion(success, msg, true)
            }
            
        case .hideApp:
            guard let app = task.targetApp else {
                completion(false, "No target application specified.", true)
                return
            }
            ApplicationService.shared.hideApp(name: app) { success, msg in
                completion(success, msg, true)
            }
            
        case .activateApp:
            guard let app = task.targetApp else {
                completion(false, "No target application specified.", true)
                return
            }
            ApplicationService.shared.activateApp(name: app) { success, msg in
                completion(success, msg, true)
            }
            
        case .openFolder:
            guard let folder = task.folder else {
                completion(false, "No folder specified.", true)
                return
            }
            FinderService.shared.openFolder(name: folder) { success, msg in
                completion(success, msg, true)
            }
            
        case .openFile:
            guard let file = task.file else {
                completion(false, "No file path specified.", true)
                return
            }
            let trimmed = file.trimmingCharacters(in: .whitespacesAndNewlines)
            let fileURL = URL(fileURLWithPath: trimmed)
            guard FileManager.default.fileExists(atPath: trimmed) else {
                completion(false, "File does not exist at path: \(trimmed)", true)
                return
            }
            DispatchQueue.main.async {
                if NSWorkspace.shared.open(fileURL) {
                    completion(true, "Opening file \(fileURL.lastPathComponent).", true)
                } else {
                    completion(false, "Failed to open file: \(fileURL.lastPathComponent).", true)
                }
            }
            
        case .revealFile:
            guard let file = task.file else {
                completion(false, "No file path specified.", true)
                return
            }
            FinderService.shared.revealFile(atPath: file) { success, msg in
                completion(success, msg, true)
            }
            
        case .openWebsite:
            guard let webString = task.website, let url = URL(string: webString) else {
                completion(false, "No website URL specified.", true)
                return
            }
            BrowserAutomationService.shared.openWebsite(url, inBrowser: task.targetApp) { success, msg in
                completion(success, msg, true)
            }
            
        case .searchWebsite:
            guard let site = task.website else {
                completion(false, "No search website specified.", true)
                return
            }
            let query = task.searchQuery ?? ""
            BrowserAutomationService.shared.searchWebsite(site: site, query: query, inBrowser: task.targetApp) { success, msg in
                completion(success, msg, true)
            }
            
        case .openSystemSettings:
            SystemService.shared.openSystemSettings { success, msg in
                completion(success, msg, true)
            }
            
        case .lockScreen:
            SystemService.shared.lockScreen { success, msg in
                completion(success, msg, true)
            }
            
        case .sleepMac:
            SystemService.shared.sleepMac { success, msg in
                completion(success, msg, true)
            }
        }
    }
}
