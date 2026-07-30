import Foundation

struct Command: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let description: String
    let iconName: String
    let category: String
    
    init(id: UUID = UUID(), title: String, description: String, iconName: String, category: String) {
        self.id = id
        self.title = title
        self.description = description
        self.iconName = iconName
        self.category = category
    }
}
