import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var commandService = CommandService.shared
    
    @State private var selectedTab = 0
    @State private var modelInput: String = AIService.shared.modelName
    @State private var newKeyInput: String = ""
    @State private var isKeySaved: Bool = KeychainHelper.shared.isKeyConfigured()
    @State private var statusMessage: String = ""
    @State private var isError: Bool = false
    @State private var showClearConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector Row
            HStack(spacing: 20) {
                Button(action: { selectedTab = 0 }) {
                    VStack(spacing: 4) {
                        Text("General & AI")
                            .font(.system(size: 14, weight: selectedTab == 0 ? .bold : .medium))
                            .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.6))
                        
                        Rectangle()
                            .fill(selectedTab == 0 ? Color.cyan : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: { selectedTab = 1 }) {
                    VStack(spacing: 4) {
                        Text("Help & Commands")
                            .font(.system(size: 14, weight: selectedTab == 1 ? .bold : .medium))
                            .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.6))
                        
                        Rectangle()
                            .fill(selectedTab == 1 ? Color.cyan : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Settings")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Tab Content Switcher
            if selectedTab == 0 {
                generalAndAITab
            } else {
                helpAndCommandsTab
            }
        }
        .frame(width: 440, height: 480)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                .ignoresSafeArea()
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .alert(isPresented: $showClearConfirmation) {
            Alert(
                title: Text("Clear Command History"),
                message: Text("Are you sure you want to clear your command history? This cannot be undone."),
                primaryButton: .destructive(Text("Clear")) {
                    commandService.clearHistory()
                    statusMessage = "Command history cleared successfully."
                    isError = false
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private var generalAndAITab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Configurable Toggles
                VStack(spacing: 14) {
                    Toggle(isOn: $chatService.isAIEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Enable AI Answers")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Use Gemini to answer unrecognized inputs")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .accessibilityLabel("Enable AI Answers")
                    
                    Toggle(isOn: $chatService.isVoiceRepliesEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Spoken Voice Replies")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Speak replies using speech synthesizer")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .accessibilityLabel("Spoken Voice Replies")
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Model Configuration
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gemini Model Configuration")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    TextField("Model Name (e.g. gemini-3.6-flash)", text: $modelInput)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                        .foregroundColor(.white)
                        .font(.system(size: 12, design: .monospaced))
                        .onChange(of: modelInput) { newValue in
                            AIService.shared.modelName = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        .accessibilityLabel("Gemini Model Name")
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // API Credentials (macOS Keychain)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gemini API Key (Secure Keychain)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    if isKeySaved {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("API Key Stored Safely in Keychain")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Button(action: {
                                KeychainHelper.shared.deleteKey()
                                isKeySaved = false
                                statusMessage = "API Key cleared from Keychain."
                                isError = false
                            }) {
                                Text("Clear Key")
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.red.opacity(0.2))
                                    .cornerRadius(6)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear API Key")
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("Paste Gemini API Key...", text: $newKeyInput)
                                .textFieldStyle(.plain)
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(6)
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                                .accessibilityLabel("Gemini API Key Secure Input")
                            
                            Button(action: {
                                let trimmed = newKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed.isEmpty {
                                    statusMessage = "API Key cannot be empty."
                                    isError = true
                                } else {
                                    let success = KeychainHelper.shared.saveKey(trimmed)
                                    if success {
                                        isKeySaved = true
                                        newKeyInput = ""
                                        statusMessage = "API key configured successfully!"
                                        isError = false
                                    } else {
                                        statusMessage = "Failed to save to Keychain."
                                        isError = true
                                    }
                                }
                            }) {
                                Text("Save Key Securely")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.cyan)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Save Key Securely")
                        }
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Clear Command History & Privacy Notice
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Command History")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear Command History")
                    
                    // Local Privacy Disclaimer
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Orbit stores command history only on this Mac.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.top, 4)
                }
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isError ? .red : .green)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding(20)
        }
    }
    
    private var helpAndCommandsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Supported Orbit Commands")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Orbit supports both voice inputs (via the center microphone) and typed queries. Try these allowlisted commands:")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(4)
                
                // Command directories
                Group {
                    commandHelpItem(title: "Greetings", items: [
                        "\"hello\" or \"hi\" — Greet Orbit"
                    ])
                    
                    commandHelpItem(title: "System Status & Time", items: [
                        "\"what time is it\" — Current local time",
                        "\"what is today's date\" — Current local date"
                    ])
                    
                    commandHelpItem(title: "Application Launchers", items: [
                        "\"open finder\" — Launch macOS Finder",
                        "\"open safari\" / \"open chrome\" — Launch browsers",
                        "\"open notes\" / \"open calendar\" — Productivity apps",
                        "\"open spotify\" — Play music (if installed)"
                    ])
                    
                    commandHelpItem(title: "System Directory Shortcuts", items: [
                        "\"open downloads\" — Open Downloads folder",
                        "\"open documents\" — Open Documents folder"
                    ])
                    
                    commandHelpItem(title: "Web Navigation & Searches", items: [
                        "\"open google\" / \"open youtube\" / \"open github\" / \"open gmail\"",
                        "\"search for [query]\" — Search Google for specific terms"
                    ])
                    
                    commandHelpItem(title: "Task Reminders (EventKit)", items: [
                        "\"remind me in [X] minutes to [task]\" — Set relative duration task",
                        "\"remind me tomorrow at [time] to [task]\" — Set calendar day task"
                    ])
                    
                    commandHelpItem(title: "General AI Conversational Support", items: [
                        "Any unrecognized commands will automatically route to Gemini AI (if enabled & key is configured) to give smart, contextual responses."
                    ])
                }
            }
            .padding(20)
        }
    }
    
    private func commandHelpItem(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.cyan)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(.white.opacity(0.4))
                        Text(item)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 6)
        }
        .padding(.vertical, 4)
    }
}
