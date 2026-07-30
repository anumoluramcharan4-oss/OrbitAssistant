import Foundation
import Combine
import Speech
import AVFoundation

class ChatService: ObservableObject {
    static let shared = ChatService()
    
    @Published var messages: [ChatMessage] = [
        ChatMessage(text: "Hello! I am Orbit, your native macOS assistant. How can I help you today?", sender: .assistant)
    ]
    @Published var isProcessing: Bool = false
    @Published var statusLabel: String = "Ready to help"
    @Published var focusInputTrigger: Bool = false
    
    @Published var isAIEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAIEnabled, forKey: "com.orbit.isAIEnabled")
        }
    }
    
    @Published var isVoiceRepliesEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isVoiceRepliesEnabled, forKey: "com.orbit.isVoiceRepliesEnabled")
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func focusInput() {
        DispatchQueue.main.async {
            self.focusInputTrigger.toggle()
        }
    }
    
    private init() {
        self.isAIEnabled = UserDefaults.standard.object(forKey: "com.orbit.isAIEnabled") as? Bool ?? true
        self.isVoiceRepliesEnabled = UserDefaults.standard.object(forKey: "com.orbit.isVoiceRepliesEnabled") as? Bool ?? true
        
        // Subscribe to speech service states to coordinate status labels and indicator states
        SpeechService.shared.$isListening
            .receive(on: RunLoop.main)
            .sink { [weak self] isListening in
                guard let self = self else { return }
                if isListening {
                    self.statusLabel = "Listening..."
                    self.isProcessing = true
                } else {
                    if self.statusLabel == "Listening..." {
                        self.statusLabel = "Ready to help"
                        self.isProcessing = false
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func toggleSpeechRecognition() {
        if SpeechService.shared.isListening {
            SpeechService.shared.stopRecognition()
        } else {
            // Setup callbacks
            SpeechService.shared.onTranscriptionComplete = { [weak self] text in
                self?.sendVoiceCommand(text)
            }
            SpeechService.shared.onError = { [weak self] errorMsg in
                self?.handleVoiceError(errorMsg)
            }
            
            SpeechService.shared.startRecognition()
        }
    }
    
    private func handleVoiceError(_ errorMsg: String) {
        self.isProcessing = false
        self.statusLabel = "Ready to help"
        let friendlyMsg = "⚠️ Voice Recognition Error: \(errorMsg)"
        self.messages.append(ChatMessage(text: friendlyMsg, sender: .assistant))
        if self.isVoiceRepliesEnabled {
            SpeechService.shared.speak("Voice recognition failed.")
        }
    }
    
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        SpeechService.shared.stopSpeaking()
        
        let userMsg = ChatMessage(text: text, sender: .user)
        messages.append(userMsg)
        
        isProcessing = true
        statusLabel = "Thinking..."
        
        // INTERCEPT DAILY BRIEFING: Check if user query matches briefing commands
        if isBriefingQuery(text) {
            triggerDailyBriefing(speakResult: false)
            return
        }
        
        // INTERCEPT REMINDERS: Check if user query matches reminder trigger
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("remind me") {
            handleReminderInput(text, speakRequest: false)
            return
        }
        
        let result = CommandRouter.shared.route(text)
        let isLocalCommand = result.commandToRegister != nil || result.responseText != "I don’t know how to do that yet, but I’m learning."
        
        if isLocalCommand {
            Just(())
                .delay(for: .seconds(0.6), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    if let command = result.commandToRegister {
                        CommandService.shared.addCommand(command)
                    }
                    self.messages.append(ChatMessage(text: result.responseText, sender: .assistant))
                    self.isProcessing = false
                    self.statusLabel = "Ready to help"
                }
                .store(in: &cancellables)
        } else {
            // Handle unrecognized queries
            handleUnrecognizedCommand(text, speakResult: false)
        }
    }
    
    private func sendVoiceCommand(_ text: String) {
        let userMsg = ChatMessage(text: text, sender: .user)
        messages.append(userMsg)
        
        isProcessing = true
        statusLabel = "Processing voice..."
        
        // INTERCEPT DAILY BRIEFING: Check if voice query matches briefing commands
        if isBriefingQuery(text) {
            triggerDailyBriefing(speakResult: true)
            return
        }
        
        // INTERCEPT REMINDERS: Check if voice query matches reminder trigger
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("remind me") {
            handleReminderInput(text, speakRequest: true)
            return
        }
        
        let result = CommandRouter.shared.route(text)
        let isLocalCommand = result.commandToRegister != nil || result.responseText != "I don’t know how to do that yet, but I’m learning."
        
        if isLocalCommand {
            Just(())
                .delay(for: .seconds(0.5), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    if let command = result.commandToRegister {
                        CommandService.shared.addCommand(command)
                    }
                    self.messages.append(ChatMessage(text: result.responseText, sender: .assistant))
                    if self.isVoiceRepliesEnabled {
                        SpeechService.shared.speak(result.responseText)
                    }
                    self.isProcessing = false
                    self.statusLabel = "Ready to help"
                }
                .store(in: &cancellables)
        } else {
            handleUnrecognizedCommand(text, speakResult: true)
        }
    }
    
    private func handleReminderInput(_ query: String, speakRequest: Bool) {
        isProcessing = false
        statusLabel = "Ready to help"
        
        if let reminder = ReminderService.shared.parseReminder(query: query) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let dateStr = formatter.string(from: reminder.targetDate)
            
            let confirmationMsg = ChatMessage(
                text: "Confirm Reminder Request",
                sender: .assistant,
                isReminderConfirmation: true,
                reminderText: reminder.text,
                reminderDate: reminder.targetDate
            )
            messages.append(confirmationMsg)
            
            if speakRequest && isVoiceRepliesEnabled {
                SpeechService.shared.speak("Do you want to create a reminder: \(reminder.text) at \(dateStr)?")
            }
        } else {
            let errorText = "⚠️ Unrecognized Reminder: I couldn't understand the time for the reminder. Please use a clearer format, such as: 'remind me in 10 minutes to drink water' or 'remind me tomorrow at 9 AM to attend class'."
            messages.append(ChatMessage(text: errorText, sender: .assistant))
            if speakRequest && isVoiceRepliesEnabled {
                SpeechService.shared.speak("I couldn't understand the reminder format. Please try again.")
            }
        }
    }
    
    func confirmReminder(text: String, date: Date, messageId: UUID) {
        isProcessing = true
        statusLabel = "Creating reminder..."
        
        // Remove the confirmation card from chat log
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages.remove(at: index)
        }
        
        ReminderService.shared.saveReminder(text: text, date: date) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isProcessing = false
                self.statusLabel = "Ready to help"
                
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                let dateStr = formatter.string(from: date)
                
                if success {
                    let replyText = "Reminder created for \(dateStr)."
                    self.messages.append(ChatMessage(text: replyText, sender: .assistant))
                    if self.isVoiceRepliesEnabled {
                        SpeechService.shared.speak(replyText)
                    }
                    
                    // Add it as a dynamic command in recent log
                    let cmd = Command(
                        title: "Reminder: \(text)",
                        description: "Created reminder for \(dateStr)",
                        iconName: "bell.fill",
                        category: "System"
                    )
                    CommandService.shared.addCommand(cmd)
                } else {
                    let errorMsg = error?.localizedDescription ?? "Reminders access denied"
                    let errorText = "⚠️ Reminder Error: \(errorMsg)"
                    self.messages.append(ChatMessage(text: errorText, sender: .assistant))
                    if self.isVoiceRepliesEnabled {
                        SpeechService.shared.speak("Failed to save reminder. Please check permissions in System Settings.")
                    }
                }
            }
        }
    }
    
    func cancelReminder(messageId: UUID) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages.remove(at: index)
        }
        
        let replyText = "Reminder cancelled."
        messages.append(ChatMessage(text: replyText, sender: .assistant))
        if isVoiceRepliesEnabled {
            SpeechService.shared.speak("Reminder cancelled.")
        }
    }
    
    private func isBriefingQuery(_ query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "give me my daily briefing" ||
               normalized == "what is on my calendar today" ||
               normalized == "what are my upcoming reminders"
    }
    
    func triggerDailyBriefing(speakResult: Bool) {
        isProcessing = true
        statusLabel = "Fetching briefing..."
        
        CalendarService.shared.generateBriefing { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isProcessing = false
                self.statusLabel = "Ready to help"
                
                switch result {
                case .success(let briefingText):
                    self.messages.append(ChatMessage(text: briefingText, sender: .assistant))
                    if self.isVoiceRepliesEnabled && speakResult {
                        let spoken = briefingText
                            .replacingOccurrences(of: "📅", with: "Calendar:")
                            .replacingOccurrences(of: "🔔", with: "Reminders:")
                        SpeechService.shared.speak(spoken)
                    }
                    
                    // Register dynamic command to history
                    let cmd = Command(
                        title: "Daily Briefing",
                        description: "Fetched calendar and reminder updates",
                        iconName: "calendar.badge.clock",
                        category: "System"
                    )
                    CommandService.shared.addCommand(cmd)
                    
                case .failure(let error):
                    let errorText = "⚠️ Briefing Error: \(error.localizedDescription)\n\nPlease verify calendar and reminder access permissions in System Settings > Privacy & Security > Calendars/Reminders."
                    self.messages.append(ChatMessage(text: errorText, sender: .assistant))
                    if self.isVoiceRepliesEnabled && speakResult {
                        SpeechService.shared.speak("Unable to generate daily briefing. Check permissions in Settings.")
                    }
                }
            }
        }
    }
    
    private func handleUnrecognizedCommand(_ prompt: String, speakResult: Bool) {
        // 1. Verify if AI answers are enabled
        guard isAIEnabled else {
            self.isProcessing = false
            self.statusLabel = "Ready to help"
            let warningText = "AI answers are currently disabled. Enable them in Settings."
            self.messages.append(ChatMessage(text: warningText, sender: .assistant))
            if speakResult && isVoiceRepliesEnabled {
                SpeechService.shared.speak(warningText)
            }
            return
        }
        
        // 2. Verify if API Key is configured in the Keychain
        guard KeychainHelper.shared.isKeyConfigured() else {
            self.isProcessing = false
            self.statusLabel = "Ready to help"
            let warningText = "Add a Gemini API key in Settings to enable AI answers."
            self.messages.append(ChatMessage(text: warningText, sender: .assistant))
            if speakResult && isVoiceRepliesEnabled {
                SpeechService.shared.speak(warningText)
            }
            return
        }
        
        // 3. Query the real Gemini AI API using AIService
        AIService.shared.generateResponse(prompt: prompt) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isProcessing = false
                self.statusLabel = "Ready to help"
                
                switch result {
                case .success(let responseText):
                    let cleanedResponse = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.messages.append(ChatMessage(text: cleanedResponse, sender: .assistant))
                    if speakResult && self.isVoiceRepliesEnabled {
                        SpeechService.shared.speak(cleanedResponse)
                    }
                case .failure(let error):
                    let friendlyErrorText: String
                    let speakErrorText: String
                    
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            friendlyErrorText = "⚠️ Connection Error: It looks like you're offline. Please check your internet connection and try again."
                            speakErrorText = "It looks like you are offline. Please check your internet connection."
                        default:
                            friendlyErrorText = "⚠️ Network Error: Unable to complete your request (\(urlError.localizedDescription))."
                            speakErrorText = "Network request failed. Please try again."
                        }
                    } else {
                        let nsError = error as NSError
                        if nsError.code == 400 || nsError.code == 403 {
                            friendlyErrorText = "⚠️ API Key Error: Sorry, I had trouble communicating with Gemini. Please verify that your API key is correct and valid in Settings."
                            speakErrorText = "API key error. Please verify your settings."
                        } else {
                            friendlyErrorText = "⚠️ Gemini Error: \(error.localizedDescription)"
                            speakErrorText = "Sorry, I encountered an error communicating with Gemini."
                        }
                    }
                    
                    self.messages.append(ChatMessage(text: friendlyErrorText, sender: .assistant))
                    if speakResult && self.isVoiceRepliesEnabled {
                        SpeechService.shared.speak(speakErrorText)
                    }
                }
            }
        }
    }
}
