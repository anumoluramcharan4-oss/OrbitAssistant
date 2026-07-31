import Foundation
import AppKit

struct Task: Identifiable, Hashable, Codable {
    enum ActionType: String, Codable {
        case launchApp
        case closeApp
        case forceQuitApp
        case hideApp
        case activateApp
        case openWebsite
        case searchWebsite
        case openFolder
        case openFile
        case revealFile
        case openSystemSettings
        case lockScreen
        case sleepMac
    }
    
    let id: UUID
    let action: ActionType
    let targetApp: String?
    let website: String?
    let folder: String?
    let file: String?
    let searchQuery: String?
    
    init(id: UUID = UUID(), action: ActionType, targetApp: String? = nil, website: String? = nil, folder: String? = nil, file: String? = nil, searchQuery: String? = nil) {
        self.id = id
        self.action = action
        self.targetApp = targetApp
        self.website = website
        self.folder = folder
        self.file = file
        self.searchQuery = searchQuery
    }
}

class TaskPlanner {
    static let shared = TaskPlanner()
    
    private init() {}
    
    private func extractOriginalSubstring(from query: String, normalizedSub: String) -> String {
        let normalizedQuery = query.lowercased()
        if let range = normalizedQuery.range(of: normalizedSub) {
            let startDist = normalizedQuery.distance(from: normalizedQuery.startIndex, to: range.lowerBound)
            let endDist = normalizedQuery.distance(from: normalizedQuery.startIndex, to: range.upperBound)
            
            let originalStart = query.index(query.startIndex, offsetBy: startDist)
            let originalEnd = query.index(query.startIndex, offsetBy: endDist)
            return String(query[originalStart..<originalEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return normalizedSub
    }
    
    func splitQueryIntoPhrases(_ query: String) -> [String] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let connectors = ["after that", "then", "next", "and"]
        var phrases = [normalized]
        
        for connector in connectors {
            var nextPhrases: [String] = []
            for phrase in phrases {
                let delimiter = "||||"
                let replaced = phrase.replacingOccurrences(
                    of: "\\b\(connector)\\b",
                    with: delimiter,
                    options: [.regularExpression, .caseInsensitive]
                )
                let splitParts = replaced.components(separatedBy: delimiter)
                nextPhrases.append(contentsOf: splitParts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
            }
            phrases = nextPhrases
        }
        
        return phrases
    }
    
    func parsePhrase(_ phrase: String, originalQuery: String, previousTasks: [Task]) -> Task? {
        let normalized = phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        var remainingText = normalized
        var targetBrowser: String? = nil
        
        let browserPatterns = [
            "in safari", "on safari", "using safari", "with safari",
            "in chrome", "on chrome", "using chrome", "with chrome",
            "in brave", "on brave", "using brave", "with brave",
            "in arc", "on arc", "using arc", "with arc"
        ]
        
        for pattern in browserPatterns {
            if let range = remainingText.range(of: "\\b\(pattern)\\b", options: .regularExpression) {
                if pattern.contains("safari") { targetBrowser = "safari" }
                else if pattern.contains("chrome") { targetBrowser = "chrome" }
                else if pattern.contains("brave") { targetBrowser = "brave" }
                else if pattern.contains("arc") { targetBrowser = "arc" }
                remainingText.removeSubrange(range)
                break
            }
        }
        
        remainingText = remainingText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        
        func removeFillers(_ text: String) -> String {
            var temp = text
            let fillers = ["please", "can you", "for me", "the"]
            for filler in fillers {
                temp = temp.replacingOccurrences(of: "\\b\(filler)\\b", with: "", options: [.regularExpression, .caseInsensitive])
            }
            temp = temp.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            return temp.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        remainingText = removeFillers(remainingText)
        
        let appsAllowlist = [
            "safari": "safari",
            "finder": "finder",
            "notes": "notes",
            "textedit": "textedit",
            "terminal": "terminal",
            "vs code": "vscode",
            "vscode": "vscode",
            "visual studio code": "vscode",
            "calculator": "calculator",
            "system settings": "system settings",
            "system preferences": "system settings",
            "settings": "system settings",
            "google chrome": "chrome",
            "chrome": "chrome",
            "brave": "brave",
            "arc": "arc",
            "mail": "mail",
            "calendar": "calendar",
            "spotify": "spotify"
        ]
        
        // System Actions Detection
        if remainingText == "sleep" || remainingText == "sleep mac" || remainingText == "sleep computer" || remainingText == "sleep my mac" {
            return Task(action: .sleepMac)
        }
        if remainingText == "lock screen" || remainingText == "lock mac" || remainingText == "lock computer" || remainingText == "lock my mac" {
            return Task(action: .lockScreen)
        }
        if remainingText == "open system settings" || remainingText == "open settings" || remainingText == "open preferences" || remainingText == "open system preferences" {
            return Task(action: .openSystemSettings)
        }
        
        // Hide Actions Detection
        let isHide = remainingText.hasPrefix("hide ") || remainingText.hasPrefix("minimize ")
        if isHide {
            var appTerm = remainingText.hasPrefix("hide ") ? String(remainingText.dropFirst(5)) : String(remainingText.dropFirst(9))
            appTerm = appTerm.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var parsedApp: String? = nil
            for (key, appName) in appsAllowlist {
                if appTerm == key || appTerm.contains(key) {
                    parsedApp = appName
                    break
                }
            }
            if let app = parsedApp {
                return Task(action: .hideApp, targetApp: app)
            }
        }
        
        // Activate / Bring to Front Actions Detection
        let isActivate = remainingText.hasPrefix("activate ") || remainingText.hasPrefix("bring ") || remainingText.hasPrefix("maximize ") || remainingText.hasPrefix("unhide ")
        if isActivate {
            var appTerm = remainingText
            let verbs = ["activate", "bring to front", "bring to foreground", "bring", "maximize", "unhide"]
            for v in verbs {
                if appTerm.hasPrefix(v) {
                    appTerm = String(appTerm.dropFirst(v.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            if appTerm.hasSuffix("to front") {
                appTerm = String(appTerm.dropLast(8)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if appTerm.hasSuffix("to foreground") {
                appTerm = String(appTerm.dropLast(13)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            var parsedApp: String? = nil
            for (key, appName) in appsAllowlist {
                if appTerm == key || appTerm.contains(key) {
                    parsedApp = appName
                    break
                }
            }
            if let app = parsedApp {
                return Task(action: .activateApp, targetApp: app)
            }
        }
        
        // Close Actions Detection
        let hasClose = remainingText.contains("close") || remainingText.contains("quit") || remainingText.contains("terminate") || remainingText.contains("exit") || remainingText.contains("stop")
        if hasClose {
            var contentText = remainingText
            let closeKeywords = ["close", "quit", "terminate", "exit", "stop"]
            for kw in closeKeywords {
                if contentText.hasPrefix(kw) {
                    contentText = String(contentText.dropFirst(kw.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            
            var resolvedTarget = contentText
            if contentText == "browser" || contentText == "the browser" {
                resolvedTarget = "safari" // default
                let browsers = ["arc", "brave", "chrome", "safari"]
                for b in browsers {
                    if let info = ApplicationService.shared.supportedApps[b] {
                        let runs = NSRunningApplication.runningApplications(withBundleIdentifier: info.bundleId)
                        if !runs.filter({ $0.activationPolicy == .regular }).isEmpty {
                            resolvedTarget = b
                            break
                        }
                    }
                }
            }
            
            var parsedApp: String? = nil
            for (key, appName) in appsAllowlist {
                if resolvedTarget == key || resolvedTarget.contains(key) {
                    parsedApp = appName
                    break
                }
            }
            if let app = parsedApp {
                return Task(action: .closeApp, targetApp: app)
            }
        }
        
        // Reveal Actions Detection
        let hasReveal = remainingText.contains("reveal") || remainingText.contains("show in finder") || remainingText.contains("find in finder")
        if hasReveal {
            var contentText = remainingText
            let revealKeywords = ["reveal file", "reveal", "show in finder", "find in finder"]
            for kw in revealKeywords {
                if contentText.hasPrefix(kw) {
                    contentText = String(contentText.dropFirst(kw.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            if contentText.hasSuffix("in finder") {
                contentText = String(contentText.dropLast(9)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            let originalFile = extractOriginalSubstring(from: originalQuery, normalizedSub: contentText)
            return Task(action: .revealFile, file: originalFile)
        }
        
        // Search Actions Detection
        let hasSearch = remainingText.contains("search") || remainingText.contains("look up") || (remainingText.range(of: "\\bfind\\b", options: .regularExpression) != nil)
        if hasSearch {
            var queryText = remainingText
            let searchPhrases = ["search for", "search", "look up", "find"]
            for phrase in searchPhrases {
                if queryText.hasPrefix(phrase) {
                    queryText = String(queryText.dropFirst(phrase.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            
            let originalSearchQuery = extractOriginalSubstring(from: originalQuery, normalizedSub: queryText)
            var resolvedSite: String? = nil
            let allowedSites = ["amazon", "youtube", "github", "google"]
            
            for site in allowedSites {
                let pattern1 = "^\(site) (?:for )?(.+)$"
                let pattern2 = "^(?:for )?(.+) (?:on|in|at|using) \(site)$"
                
                if let regex1 = try? NSRegularExpression(pattern: pattern1, options: .caseInsensitive),
                   let match = regex1.firstMatch(in: queryText, options: [], range: NSRange(queryText.startIndex..<queryText.endIndex, in: queryText)) {
                    if let r = Range(match.range(at: 1), in: queryText) {
                        resolvedSite = site
                        let cleanSub = String(queryText[r])
                        let finalQuery = extractOriginalSubstring(from: originalQuery, normalizedSub: cleanSub)
                        return Task(action: .searchWebsite, targetApp: targetBrowser, website: site, searchQuery: finalQuery)
                    }
                }
                
                if let regex2 = try? NSRegularExpression(pattern: pattern2, options: .caseInsensitive),
                   let match = regex2.firstMatch(in: queryText, options: [], range: NSRange(queryText.startIndex..<queryText.endIndex, in: queryText)) {
                    if let r = Range(match.range(at: 1), in: queryText) {
                        resolvedSite = site
                        let cleanSub = String(queryText[r])
                        let finalQuery = extractOriginalSubstring(from: originalQuery, normalizedSub: cleanSub)
                        return Task(action: .searchWebsite, targetApp: targetBrowser, website: site, searchQuery: finalQuery)
                    }
                }
            }
            
            if resolvedSite == nil {
                for prevTask in previousTasks.reversed() {
                    if prevTask.action == .openWebsite, let prevWeb = prevTask.website {
                        if prevWeb.contains("amazon.com") { resolvedSite = "amazon" }
                        else if prevWeb.contains("youtube.com") { resolvedSite = "youtube" }
                        else if prevWeb.contains("github.com") { resolvedSite = "github" }
                        else if prevWeb.contains("google.com") { resolvedSite = "google" }
                        break
                    }
                }
            }
            
            if let site = resolvedSite {
                return Task(action: .searchWebsite, targetApp: targetBrowser, website: site, searchQuery: originalSearchQuery)
            } else {
                return Task(action: .searchWebsite, targetApp: targetBrowser, website: "google", searchQuery: originalSearchQuery)
            }
        }
        
        // Open Actions Detection
        let hasOpen = remainingText.contains("open") || remainingText.contains("launch") || remainingText.contains("start") || remainingText.contains("run") || remainingText.contains("focus")
        if hasOpen {
            var contentText = remainingText
            let openKeywords = ["open", "launch", "start", "run", "focus"]
            for kw in openKeywords {
                if contentText.hasPrefix(kw) {
                    contentText = String(contentText.dropFirst(kw.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
            
            if contentText.isEmpty && targetBrowser != nil {
                return Task(action: .launchApp, targetApp: targetBrowser)
            }
            
            // Downloads / Documents / Desktop
            if contentText == "downloads" || contentText == "documents" || contentText == "desktop" {
                return Task(action: .openFolder, folder: contentText)
            }
            
            let looksLikeFile = contentText.hasPrefix("/") || contentText.hasPrefix("~") || contentText.hasPrefix(".") || (contentText.contains(".") && !contentText.hasSuffix(".com") && !contentText.hasSuffix(".org") && !contentText.hasSuffix(".net"))
            if looksLikeFile {
                let originalFile = extractOriginalSubstring(from: originalQuery, normalizedSub: contentText)
                return Task(action: .openFile, file: originalFile)
            }
            
            let originalWebText = extractOriginalSubstring(from: originalQuery, normalizedSub: contentText)
            if let url = BrowserService.shared.validateAndNormalizeURL(originalWebText) {
                return Task(action: .openWebsite, targetApp: targetBrowser, website: url.absoluteString)
            }
            
            var resolvedTarget = contentText
            if contentText == "browser" || contentText == "the browser" {
                resolvedTarget = "safari" // default
                let browsers = ["arc", "brave", "chrome", "safari"]
                for b in browsers {
                    if let info = ApplicationService.shared.supportedApps[b] {
                        let runs = NSRunningApplication.runningApplications(withBundleIdentifier: info.bundleId)
                        if !runs.filter({ $0.activationPolicy == .regular }).isEmpty {
                            resolvedTarget = b
                            break
                        }
                    }
                }
            }
            
            var parsedApp: String? = nil
            for (key, appName) in appsAllowlist {
                if resolvedTarget == key || resolvedTarget.contains(key) {
                    parsedApp = appName
                    break
                }
            }
            if let app = parsedApp {
                return Task(action: .launchApp, targetApp: app)
            }
        }
        
        return nil
    }
    
    func plan(query: String) -> [Task] {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Expansion of close all browsers
        if normalized == "close all browsers" || normalized == "quit all browsers" {
            return [
                Task(action: .closeApp, targetApp: "safari"),
                Task(action: .closeApp, targetApp: "chrome"),
                Task(action: .closeApp, targetApp: "brave"),
                Task(action: .closeApp, targetApp: "arc")
            ]
        }
        
        let phrases = splitQueryIntoPhrases(query)
        var tasks: [Task] = []
        
        for phrase in phrases {
            if let task = parsePhrase(phrase, originalQuery: query, previousTasks: tasks) {
                tasks.append(task)
            }
        }
        
        return tasks
    }
}
