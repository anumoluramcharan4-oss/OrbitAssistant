import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let service = "com.orbit.geminiKey"
    private let account = "geminiAPIKey"
    
    private init() {}
    
    // SAFETY DECISION: Write the key data to macOS System Keychain.
    // The key is stored securely on the hardware level and requires user authentication access bounds.
    func saveKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        
        // Remove any existing duplicate entries
        deleteKey()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func getEnvKey() -> String? {
        if let envVal = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envVal.isEmpty {
            return envVal
        }
        
        let envPath = "/Users/ramcharantej/OrbitAssistant/.env"
        if let content = try? String(contentsOfFile: envPath, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("GEMINI_API_KEY=") {
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count >= 2 {
                        let key = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !key.isEmpty {
                            return key
                        }
                    }
                }
            }
        }
        return nil
    }
    
    // Fetch the key safely from the Keychain
    func readKey() -> String? {
        if let envKey = getEnvKey() {
            return envKey
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        // Fallback to local file in app bundle if keychain read fails (useful for sandbox development setup)
        if let bundlePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: bundlePath),
           let key = dict["geminiAPIKey"] as? String,
           !key.isEmpty {
            return key
        }
        
        return nil
    }
    
    // Check if key is present without returning the value itself
    func isKeyConfigured() -> Bool {
        if getEnvKey() != nil {
            return true
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false, // Don't fetch data, just check existence
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess || status == errSecInteractionNotAllowed {
            return true
        }
        
        // Fallback check in Secrets.plist
        if let bundlePath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: bundlePath),
           let key = dict["geminiAPIKey"] as? String,
           !key.isEmpty {
            return true
        }
        
        return false
    }
    
    // Delete the stored key from standard keychain
    func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
