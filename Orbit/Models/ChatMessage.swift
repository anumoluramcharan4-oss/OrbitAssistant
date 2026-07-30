import Foundation

enum MessageSender: Hashable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let text: String
    let sender: MessageSender
    let timestamp: Date
    
    // Metadata properties to support interactive reminder scheduling cards
    let isReminderConfirmation: Bool
    let reminderText: String?
    let reminderDate: Date?
    
    init(
        id: UUID = UUID(),
        text: String,
        sender: MessageSender,
        timestamp: Date = Date(),
        isReminderConfirmation: Bool = false,
        reminderText: String? = nil,
        reminderDate: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.sender = sender
        self.timestamp = timestamp
        self.isReminderConfirmation = isReminderConfirmation
        self.reminderText = reminderText
        self.reminderDate = reminderDate
    }
}
