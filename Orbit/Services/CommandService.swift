import Foundation

class CommandService: ObservableObject {
    static let shared = CommandService()
    
    @Published var commands: [Command] = []
    
    private init() {
        // Load persisted commands from local storage
        let loaded = CommandHistoryStore.shared.loadHistory()
        if loaded.isEmpty {
            // Load templates if no history exists yet
            self.commands = getSampleCommands()
            CommandHistoryStore.shared.saveHistory(self.commands)
        } else {
            self.commands = loaded
        }
    }
    
    func addCommand(_ command: Command) {
        // Prevent duplicate commands (case-insensitive check)
        guard !commands.contains(where: { $0.title.lowercased() == command.title.lowercased() }) else { return }
        
        DispatchQueue.main.async {
            self.commands.insert(command, at: 0)
            
            // Limit history to a maximum of 20 items
            if self.commands.count > 20 {
                self.commands = Array(self.commands.prefix(20))
            }
            
            // Persist the updated command list
            CommandHistoryStore.shared.saveHistory(self.commands)
        }
    }
    
    func clearHistory() {
        DispatchQueue.main.async {
            self.commands = []
            CommandHistoryStore.shared.clearHistory()
        }
    }
    
    private func getSampleCommands() -> [Command] {
        return [
            Command(
                title: "Summarize Window",
                description: "Analyze and summarize the frontmost app window",
                iconName: "doc.text.magnifyingglass",
                category: "Productivity"
            ),
            Command(
                title: "Clean Desktop",
                description: "Organize messy files on your Desktop into folders",
                iconName: "square.grid.3x3.fill",
                category: "System"
            ),
            Command(
                title: "Draft Email",
                description: "Compose a follow-up reply in Mail",
                iconName: "envelope.fill",
                category: "Communication"
            ),
            Command(
                title: "Check Resources",
                description: "Inspect RAM, CPU usage, and battery health",
                iconName: "cpu",
                category: "System"
            ),
            Command(
                title: "Set Timer",
                description: "Start a focus timer for 25 minutes",
                iconName: "timer",
                category: "Utilities"
            ),
            Command(
                title: "Open Xcode",
                description: "Launch Xcode and open the active workspace",
                iconName: "hammer.fill",
                category: "Developer"
            ),
            Command(
                title: "Optimize Space",
                description: "Identify large cache files for deletion",
                iconName: "trash.fill",
                category: "System"
            )
        ]
    }
}
