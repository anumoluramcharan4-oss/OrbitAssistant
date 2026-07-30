import Foundation
import EventKit

struct ExtractedReminder {
    let text: String
    let targetDate: Date
}

class ReminderService {
    static let shared = ReminderService()
    private let eventStore = EKEventStore()
    
    private init() {}
    
    // Parses user command text using regex matching.
    // Handles relative durations ("in 10 minutes") and calendar components ("tomorrow at 9 am")
    func parseReminder(query: String) -> ExtractedReminder? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Format A: "remind me in [X] [minutes/hours/days] to [task]"
        // Example: remind me in 10 minutes to drink water
        if let regexA = try? NSRegularExpression(pattern: #"^remind me in\s+(\d+)\s+(minute|minutes|hour|hours|day|days)\s+to\s+(.+)$"#, options: .caseInsensitive) {
            let nsString = trimmed as NSString
            let results = regexA.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges == 4 {
                let qtyStr = nsString.substring(with: match.range(at: 1))
                let unit = nsString.substring(with: match.range(at: 2)).lowercased()
                let task = nsString.substring(with: match.range(at: 3))
                
                guard let qty = Double(qtyStr) else { return nil }
                
                var seconds: TimeInterval = 0
                if unit.hasPrefix("minute") {
                    seconds = qty * 60
                } else if unit.hasPrefix("hour") {
                    seconds = qty * 3600
                } else if unit.hasPrefix("day") {
                    seconds = qty * 86400
                }
                
                let targetDate = Date().addingTimeInterval(seconds)
                return ExtractedReminder(text: task, targetDate: targetDate)
            }
        }
        
        // Format B: "remind me tomorrow at [hour]:[minute] [am/pm] to [task]"
        // Example: remind me tomorrow at 9 AM to attend class
        // Example: remind me tomorrow at 9:30 PM to study
        if let regexB = try? NSRegularExpression(pattern: #"^remind me tomorrow at\s+(\d+)(?::(\d+))?\s*(am|pm)\s+to\s+(.+)$"#, options: .caseInsensitive) {
            let nsString = trimmed as NSString
            let results = regexB.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length))
            if let match = results.first, match.numberOfRanges == 5 {
                let hourStr = nsString.substring(with: match.range(at: 1))
                
                let minRange = match.range(at: 2)
                let minStr = minRange.location != NSNotFound ? nsString.substring(with: minRange) : "0"
                
                let amPm = nsString.substring(with: match.range(at: 3)).lowercased()
                let task = nsString.substring(with: match.range(at: 4))
                
                guard var hour = Int(hourStr), let minute = Int(minStr) else { return nil }
                
                if amPm == "pm" && hour < 12 {
                    hour += 12
                } else if amPm == "am" && hour == 12 {
                    hour = 0
                }
                
                let calendar = Calendar.current
                var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: calendar.date(byAdding: .day, value: 1, to: Date())!)
                tomorrowComponents.hour = hour
                tomorrowComponents.minute = minute
                tomorrowComponents.second = 0
                
                if let targetDate = calendar.date(from: tomorrowComponents) {
                    return ExtractedReminder(text: task, targetDate: targetDate)
                }
            }
        }
        
        return nil
    }
    
    // Triggers permission requests. Safely switches between macOS 13 and macOS 14+ access APIs to avoid compile warnings.
    func requestPermission(completion: @escaping (Bool, Error?) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToReminders { granted, error in
                completion(granted, error)
            }
        } else {
            eventStore.requestAccess(to: .reminder) { granted, error in
                completion(granted, error)
            }
        }
    }
    
    // Saves a reminder in the default macOS calendar
    func saveReminder(text: String, date: Date, completion: @escaping (Bool, Error?) -> Void) {
        requestPermission { [weak self] granted, error in
            guard let self = self else { return }
            guard granted else {
                let deniedError = error ?? NSError(
                    domain: "ReminderService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Reminders permission denied. Please enable Reminders access in System Settings > Privacy & Security > Reminders."]
                )
                completion(false, deniedError)
                return
            }
            
            let reminder = EKReminder(eventStore: self.eventStore)
            reminder.title = text
            reminder.calendar = self.eventStore.defaultCalendarForNewReminders()
            
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            reminder.dueDateComponents = components
            
            // Set alarm reminder
            let alarm = EKAlarm(absoluteDate: date)
            reminder.addAlarm(alarm)
            
            do {
                try self.eventStore.save(reminder, commit: true)
                completion(true, nil)
            } catch {
                completion(false, error)
            }
        }
    }
}
