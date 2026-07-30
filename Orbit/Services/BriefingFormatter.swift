import Foundation

struct BriefingItem {
    let title: String
    let date: Date?
}

class BriefingFormatter {
    // Generates a formatted text summary for the chat feed and voice synthesis speech strings
    static func formatBriefing(now: Date, nextEvent: BriefingItem?, reminders: [BriefingItem]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        let currentString = dateFormatter.string(from: now)
        
        var output = "Daily Briefing for \(currentString):\n\n"
        
        // Next calendar event
        if let event = nextEvent {
            let timeString: String
            if let eventDate = event.date {
                let timeFormatter = DateFormatter()
                timeFormatter.dateStyle = .none
                timeFormatter.timeStyle = .short
                timeString = timeFormatter.string(from: eventDate)
            } else {
                timeString = "unknown time"
            }
            output += "📅 Next Event: '\(event.title)' at \(timeString).\n"
        } else {
            output += "📅 Next Event: No more events scheduled for today.\n"
        }
        
        // Reminders
        if reminders.isEmpty {
            output += "🔔 Reminders: No upcoming reminders."
        } else {
            output += "🔔 Upcoming Reminders:\n"
            for (index, reminder) in reminders.enumerated() {
                var details = ""
                if let due = reminder.date {
                    let dueFormatter = DateFormatter()
                    dueFormatter.dateStyle = .short
                    dueFormatter.timeStyle = .short
                    details = " (due \(dueFormatter.string(from: due)))"
                }
                output += "  \(index + 1). \(reminder.title)\(details)\n"
            }
            output = String(output.dropLast()) // Remove trailing newline
        }
        
        return output
    }
}
