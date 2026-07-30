import Foundation
import EventKit

class CalendarService {
    static let shared = CalendarService()
    private let eventStore = EKEventStore()
    
    private init() {}
    
    // Request permission to access system calendars
    func requestCalendarPermission(completion: @escaping (Bool, Error?) -> Void) {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                completion(granted, error)
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                completion(granted, error)
            }
        }
    }
    
    // Queries calendar events scheduled for today (from now until midnight)
    func fetchTodayEvents(completion: @escaping ([EKEvent], Error?) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            completion([], nil)
            return
        }
        
        let predicate = eventStore.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        let sorted = events.sorted { $0.startDate < $1.startDate }
        completion(sorted, nil)
    }
    
    // Queries incomplete reminders from the EventKit store, returning the top 3 sorted by due dates
    func fetchUpcomingReminders(completion: @escaping ([EKReminder], Error?) -> Void) {
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        eventStore.fetchReminders(matching: predicate) { reminders in
            let incomplete = reminders ?? []
            let sorted = incomplete.sorted { (r1, r2) -> Bool in
                if let d1 = r1.dueDateComponents?.date, let d2 = r2.dueDateComponents?.date {
                    return d1 < d2
                }
                return r1.dueDateComponents?.date != nil
            }
            let limit = Array(sorted.prefix(3))
            completion(limit, nil)
        }
    }
    
    // Orchestrates permissions check and data query to compile a daily briefing
    func generateBriefing(completion: @escaping (Result<String, Error>) -> Void) {
        requestCalendarPermission { [weak self] calendarGranted, calendarError in
            guard let self = self else { return }
            guard calendarGranted else {
                let error = calendarError ?? NSError(
                    domain: "CalendarService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Calendar permission denied. Please enable Calendars access in System Settings > Privacy & Security > Calendars."]
                )
                completion(.failure(error))
                return
            }
            
            ReminderService.shared.requestPermission { [weak self] remindersGranted, remindersError in
                guard let self = self else { return }
                guard remindersGranted else {
                    let error = remindersError ?? NSError(
                        domain: "CalendarService",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Reminders permission denied. Please enable Reminders access in System Settings > Privacy & Security > Reminders."]
                    )
                    completion(.failure(error))
                    return
                }
                
                self.fetchTodayEvents { events, eventsError in
                    if let error = eventsError {
                        completion(.failure(error))
                        return
                    }
                    
                    self.fetchUpcomingReminders { reminders, remindersError in
                        if let error = remindersError {
                            completion(.failure(error))
                            return
                        }
                        
                        let nextEventItem = events.first.map { BriefingItem(title: $0.title ?? "Untitled Event", date: $0.startDate) }
                        let reminderItems = reminders.map { BriefingItem(title: $0.title ?? "Untitled Reminder", date: $0.dueDateComponents?.date) }
                        
                        let briefingText = BriefingFormatter.formatBriefing(now: Date(), nextEvent: nextEventItem, reminders: reminderItems)
                        completion(.success(briefingText))
                    }
                }
            }
        }
    }
}
