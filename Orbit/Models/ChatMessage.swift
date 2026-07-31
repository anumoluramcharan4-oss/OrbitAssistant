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
    
    // Metadata properties to support interactive file open confirmation cards
    let isFileConfirmation: Bool
    let filePath: String?
    
    // Metadata properties to support interactive force quit and sleep confirmation cards
    let isForceQuitConfirmation: Bool
    let forceQuitAppName: String?
    let isSleepConfirmation: Bool
    let isAccessibilitySettingsCard: Bool
    
    init(
        id: UUID = UUID(),
        text: String,
        sender: MessageSender,
        timestamp: Date = Date(),
        isReminderConfirmation: Bool = false,
        reminderText: String? = nil,
        reminderDate: Date? = nil,
        isFileConfirmation: Bool = false,
        filePath: String? = nil,
        isForceQuitConfirmation: Bool = false,
        forceQuitAppName: String? = nil,
        isSleepConfirmation: Bool = false,
        isAccessibilitySettingsCard: Bool = false
    ) {
        self.id = id
        self.text = text
        self.sender = sender
        self.timestamp = timestamp
        self.isReminderConfirmation = isReminderConfirmation
        self.reminderText = reminderText
        self.reminderDate = reminderDate
        self.isFileConfirmation = isFileConfirmation
        self.filePath = filePath
        self.isForceQuitConfirmation = isForceQuitConfirmation
        self.forceQuitAppName = forceQuitAppName
        self.isSleepConfirmation = isSleepConfirmation
        self.isAccessibilitySettingsCard = isAccessibilitySettingsCard
    }
}

