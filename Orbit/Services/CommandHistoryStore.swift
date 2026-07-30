import Foundation

class CommandHistoryStore {
    static let shared = CommandHistoryStore()
    
    private let userDefaultsKey = "com.orbit.commandHistory"
    private let maxHistoryCount = 20
    
    private init() {}
    
    // SAFETY DECISION: We only save command titles, descriptions, categories, and icon names.
    // Sensitive files, keyboard entries, audio files, microphone recordings, or private credentials
    // are strictly excluded from local disk caching.
    func saveHistory(_ commands: [Command]) {
        let historyToSave = Array(commands.prefix(maxHistoryCount))
        
        do {
            let data = try JSONEncoder().encode(historyToSave)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to serialize command history: \(error.localizedDescription)")
        }
    }
    
    // Loads history logs from standard storage
    func loadHistory() -> [Command] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([Command].self, from: data)
        } catch {
            print("Failed to deserialize command history: \(error.localizedDescription)")
            return []
        }
    }
    
    // Wipes all persisted command history from local defaults
    func clearHistory() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
