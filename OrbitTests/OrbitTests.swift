import XCTest
@testable import Orbit

class OrbitTests: XCTestCase {
    
    // MARK: - CommandRouter Tests
    
    func testGreetCommand() {
        let result = CommandRouter.shared.route("hello")
        XCTAssertEqual(result.responseText, "Hello! I am Orbit, your native macOS assistant. How can I help you today?")
        XCTAssertEqual(result.commandToRegister?.title, "Hi")
        
        let resultHi = CommandRouter.shared.route("hi")
        XCTAssertEqual(resultHi.responseText, "Hello! I am Orbit, your native macOS assistant. How can I help you today?")
    }
    
    func testTimeCommand() {
        let result = CommandRouter.shared.route("what time is it")
        XCTAssertTrue(result.responseText.contains("The current local time is"))
        XCTAssertEqual(result.commandToRegister?.title, "What time is it")
    }
    
    func testDateCommand() {
        let result = CommandRouter.shared.route("what is today's date")
        XCTAssertTrue(result.responseText.contains("Today's date is"))
        XCTAssertEqual(result.commandToRegister?.title, "What is today's date")
    }
    
    func testOpenGoogleCommand() {
        let result = CommandRouter.shared.route("open google")
        XCTAssertEqual(result.responseText, "Opening Google.")
        XCTAssertEqual(result.commandToRegister?.title, "Open Google")
    }
    
    func testOpenFinderCommand() {
        let result = CommandRouter.shared.route("open finder")
        XCTAssertEqual(result.responseText, "Opening and focusing Finder.")
        XCTAssertEqual(result.commandToRegister?.title, "Open Finder")
    }
    
    func testOpenSafariCommand() {
        let result = CommandRouter.shared.route("open safari")
        XCTAssertEqual(result.responseText, "Opening and focusing Safari.")
        XCTAssertEqual(result.commandToRegister?.title, "Open Safari")
    }
    
    func testOpenTextEditCommand() {
        let result = CommandRouter.shared.route("open textedit")
        XCTAssertEqual(result.responseText, "Opening and focusing TextEdit.")
        XCTAssertEqual(result.commandToRegister?.title, "Open TextEdit")
    }
    
    func testOpenChromeCommand() {
        let result = CommandRouter.shared.route("open chrome")
        if MacActionService.shared.isAppInstalled(bundleId: "com.google.Chrome") {
            XCTAssertEqual(result.responseText, "Opening and focusing Google Chrome.")
            XCTAssertEqual(result.commandToRegister?.title, "Open Google Chrome")
        } else {
            XCTAssertEqual(result.responseText, "Google Chrome is not installed on this Mac.")
            XCTAssertNil(result.commandToRegister)
        }
    }
    
    func testOpenSpotifyCommand() {
        let result = CommandRouter.shared.route("open spotify")
        if MacActionService.shared.isAppInstalled(bundleId: "com.spotify.client") {
            XCTAssertEqual(result.responseText, "Opening and focusing Spotify.")
            XCTAssertEqual(result.commandToRegister?.title, "Open Spotify")
        } else {
            XCTAssertEqual(result.responseText, "Spotify is not installed on this Mac.")
            XCTAssertNil(result.commandToRegister)
        }
    }
    
    func testUnknownCommand() {
        let result = CommandRouter.shared.route("unsupported random action")
        XCTAssertEqual(result.responseText, "I don’t know how to do that yet, but I’m learning.")
        XCTAssertNil(result.commandToRegister)
    }
    
    // MARK: - Command History Tests
    
    func testCommandHistorySave() {
        // Clear history first
        CommandService.shared.clearHistory()
        XCTAssertTrue(CommandService.shared.commands.isEmpty)
        
        // Add a command
        let testCmd = Command(title: "Test Cmd Save", description: "Desc", iconName: "star", category: "Test")
        CommandService.shared.addCommand(testCmd)
        
        // Wait for async update
        let expectation = self.expectation(description: "Command saved async")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(CommandService.shared.commands.contains(where: { $0.title == "Test Cmd Save" }))
            
            // Check persistence loading
            let loaded = CommandHistoryStore.shared.loadHistory()
            XCTAssertTrue(loaded.contains(where: { $0.title == "Test Cmd Save" }))
            
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.5)
    }
    
    func testCommandHistoryCapacityCap() {
        CommandService.shared.clearHistory()
        
        let expectation = self.expectation(description: "History cleared and 25 commands added")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(CommandService.shared.commands.isEmpty)
            
            // Add 25 unique commands
            for i in 1...25 {
                let cmd = Command(title: "Command \(i)", description: "Desc", iconName: "star", category: "Test")
                CommandService.shared.addCommand(cmd)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                XCTAssertEqual(CommandService.shared.commands.count, 20)
                
                // Verify persisted copy is also capped
                let loaded = CommandHistoryStore.shared.loadHistory()
                XCTAssertEqual(loaded.count, 20)
                
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 0.8)
    }
    
    func testCommandHistoryClear() {
        // Insert sample commands
        let cmd = Command(title: "Command to Clear", description: "Desc", iconName: "star", category: "Test")
        CommandService.shared.addCommand(cmd)
        
        let expectation1 = self.expectation(description: "Command added for clear test")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(CommandService.shared.commands.isEmpty)
            expectation1.fulfill()
        }
        waitForExpectations(timeout: 0.2)
        
        // Clear history
        CommandService.shared.clearHistory()
        
        let expectation2 = self.expectation(description: "Command history cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(CommandService.shared.commands.isEmpty)
            
            let loaded = CommandHistoryStore.shared.loadHistory()
            XCTAssertTrue(loaded.isEmpty)
            
            expectation2.fulfill()
        }
        waitForExpectations(timeout: 0.2)
    }
    
    // MARK: - ReminderService Tests
    
    func testReminderParsingFormatA() {
        let query = "remind me in 10 minutes to drink water"
        let parsed = ReminderService.shared.parseReminder(query: query)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.text, "drink water")
        
        // Assert date is roughly 10 minutes from now (within 5 seconds tolerance)
        if let targetDate = parsed?.targetDate {
            let diff = targetDate.timeIntervalSince(Date())
            XCTAssertTrue(diff >= 595 && diff <= 605)
        }
    }
    
    func testReminderParsingFormatB() {
        let query = "remind me tomorrow at 9 AM to attend class"
        let parsed = ReminderService.shared.parseReminder(query: query)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.text, "attend class")
        
        if let targetDate = parsed?.targetDate {
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
            XCTAssertEqual(calendar.component(.day, from: targetDate), calendar.component(.day, from: tomorrow))
            XCTAssertEqual(calendar.component(.hour, from: targetDate), 9)
            XCTAssertEqual(calendar.component(.minute, from: targetDate), 0)
        }
    }
    
    func testReminderParsingInvalid() {
        let query = "remind me to buy groceries" // Missing time
        let parsed = ReminderService.shared.parseReminder(query: query)
        XCTAssertNil(parsed)
    }
    
    // MARK: - BriefingFormatter Tests
    
    func testBriefingFormattingEmptyState() {
        let now = Date()
        let result = BriefingFormatter.formatBriefing(now: now, nextEvent: nil, reminders: [])
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        let expectedHeader = "Daily Briefing for \(dateFormatter.string(from: now)):"
        
        XCTAssertTrue(result.contains(expectedHeader))
        XCTAssertTrue(result.contains("📅 Next Event: No more events scheduled for today."))
        XCTAssertTrue(result.contains("🔔 Reminders: No upcoming reminders."))
    }
    
    func testBriefingFormattingFilledState() {
        let now = Date()
        let eventDate = Date().addingTimeInterval(3600) // in 1 hour
        let event = BriefingItem(title: "Staff Meeting", date: eventDate)
        
        let reminderDate = Date().addingTimeInterval(7200) // in 2 hours
        let reminders = [
            BriefingItem(title: "Submit report", date: reminderDate),
            BriefingItem(title: "Buy milk", date: nil)
        ]
        
        let result = BriefingFormatter.formatBriefing(now: now, nextEvent: event, reminders: reminders)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let expectedTime = timeFormatter.string(from: eventDate)
        
        XCTAssertTrue(result.contains("📅 Next Event: 'Staff Meeting' at \(expectedTime)."))
        XCTAssertTrue(result.contains("🔔 Upcoming Reminders:"))
        XCTAssertTrue(result.contains("1. Submit report"))
        XCTAssertTrue(result.contains("2. Buy milk"))
    }
}
