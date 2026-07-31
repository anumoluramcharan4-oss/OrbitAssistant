import Foundation
import AppKit

class FinderService {
    static let shared = FinderService()
    
    private init() {}
    
    func openFolder(name: String, completion: @escaping (Bool, String) -> Void) {
        let clean = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var folderURL: URL? = nil
        var displayName = ""
        
        if clean == "downloads" {
            folderURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            displayName = "Downloads"
        } else if clean == "documents" {
            folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            displayName = "Documents"
        } else if clean == "desktop" {
            folderURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            displayName = "Desktop"
        }
        
        guard let url = folderURL else {
            completion(false, "Folder '\(name)' is not supported.")
            return
        }
        
        DispatchQueue.main.async {
            if NSWorkspace.shared.open(url) {
                completion(true, "Opening \(displayName).")
            } else {
                completion(false, "Failed to open \(displayName) folder.")
            }
        }
    }
    
    func revealFile(atPath path: String, completion: @escaping (Bool, String) -> Void) {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            completion(false, "File does not exist at path: \(path)")
            return
        }
        
        DispatchQueue.main.async {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            completion(true, "Revealed file in Finder.")
        }
    }
}
