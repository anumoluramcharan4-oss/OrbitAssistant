import SwiftUI

struct MainView: View {
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var speechService = SpeechService.shared
    @State private var inputText: String = ""
    @State private var isInputHovered = false
    @State private var isSendHovered = false
    @State private var showSettings = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var showMicDiagnostic = false
    
    var body: some View {
        HStack(spacing: 18) {
            // Main Left Control Center Panel
            VStack(spacing: 0) {
                // Header (Title & Subtitle)
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 4) {
                        Text("Orbit")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .cyan, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .cyan.opacity(0.35), radius: 8, x: 0, y: 0)
                        
                        Text("Your personal Mac assistant")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            chatService.triggerDailyBriefing(speakResult: false)
                        }) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(8.5)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Get Daily Briefing")
                        .accessibilityLabel("Fetch Daily Briefing")
                        
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(8)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("AI Settings")
                        .accessibilityLabel("AI Setup & Settings")
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Centered Microphone & Wave Visualizer (Compact layout)
                VStack(spacing: 12) {
                    MicrophoneButton()
                    
                    // Status Label with glowing indicator dot
                    HStack(spacing: 6) {
                        Circle()
                            .fill(chatService.statusLabel == "Listening..." ? Color.red : (chatService.statusLabel.contains("Processing") ? Color.orange : Color.green))
                            .frame(width: 6, height: 6)
                            .shadow(
                                color: chatService.statusLabel == "Listening..." ? Color.red : (chatService.statusLabel.contains("Processing") ? Color.orange : Color.green),
                                radius: 4
                            )
                        
                        Text(chatService.statusLabel)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(20)
                    
                    // Microphone level meter
                    if speechService.isListening {
                        VStack(spacing: 4) {
                            HStack {
                                Text("Input Level:")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 4)
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(
                                            LinearGradient(
                                                colors: [.green, .yellow, .red],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(speechService.micLevel), height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(.horizontal, 64)
                        .transition(.opacity)
                    }
                    
                    // Live transcript display
                    if speechService.isListening && !speechService.recognizedText.isEmpty {
                        Text("Heard: \(speechService.recognizedText)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 12)
                
                // Voice error message card & diagnostics (Sequential, no overlapping)
                if let error = speechService.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            
                            Text(error)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.red)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            Spacer()
                            
                            if error.contains("No microphone audio detected") {
                                Button(action: {
                                    withAnimation {
                                        showMicDiagnostic.toggle()
                                        if showMicDiagnostic {
                                            speechService.checkPermissions { _ in }
                                        }
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "waveform.path.badge.minus")
                                        Text("Check Microphone")
                                    }
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.red.opacity(0.25))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        
                        if showMicDiagnostic && error.contains("No microphone audio detected") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Microphone Diagnostics")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.cyan)
                                    .padding(.bottom, 2)
                                
                                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                                    GridRow {
                                        Text("Permission Status:")
                                            .foregroundColor(.white.opacity(0.5))
                                        Text(speechService.micPermissionStatus)
                                            .fontWeight(.semibold)
                                            .foregroundColor(speechService.micPermissionStatus == "Authorized" ? .green : .red)
                                    }
                                    GridRow {
                                        Text("Selected Input:")
                                            .foregroundColor(.white.opacity(0.5))
                                        Text(speechService.selectedInputDeviceName)
                                    }
                                    GridRow {
                                        Text("Sample Rate:")
                                            .foregroundColor(.white.opacity(0.5))
                                        Text(String(format: "%.1f Hz", speechService.inputNodeSampleRate))
                                    }
                                    GridRow {
                                        Text("Audio Buffer Count:")
                                            .foregroundColor(.white.opacity(0.5))
                                        Text("\(speechService.audioBufferCount)")
                                    }
                                    GridRow {
                                        Text("Current Level:")
                                            .foregroundColor(.white.opacity(0.5))
                                        Text(String(format: "%.1f%%", speechService.micLevel * 100))
                                    }
                                }
                                .font(.system(size: 11, design: .monospaced))
                                
                                let isDenied = speechService.micPermissionStatus == "Denied" || speechService.micPermissionStatus == "Restricted"
                                if isDenied {
                                    Button(action: {
                                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                                            NSWorkspace.shared.open(url)
                                        } else if let fallbackUrl = URL(string: "x-apple.systempreferences:") {
                                            NSWorkspace.shared.open(fallbackUrl)
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "hand.raised.fill")
                                            Text("Open Privacy & Security Settings")
                                        }
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color.cyan)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 4)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }
                
                // Chat Message Viewer (Interactive HUD - grows/shrinks dynamically)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(chatService.messages) { message in
                                HStack {
                                    if message.isReminderConfirmation, let remText = message.reminderText, let remDate = message.reminderDate {
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "bell.badge.fill")
                                                    .foregroundColor(.cyan)
                                                Text("Create reminder:")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Text("'\(remText)'")
                                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.9))
                                                .padding(.leading, 4)
                                            
                                            HStack(spacing: 4) {
                                                Text("Scheduled:")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.white.opacity(0.5))
                                                Text(remDate, style: .date)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(.cyan)
                                                Text("at")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.white.opacity(0.5))
                                                Text(remDate, style: .time)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(.cyan)
                                            }
                                            .padding(.leading, 4)
                                            
                                            HStack(spacing: 12) {
                                                Button(action: {
                                                    chatService.confirmReminder(text: remText, date: remDate, messageId: message.id)
                                                }) {
                                                    Text("Confirm")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(.black)
                                                        .padding(.horizontal, 14)
                                                        .padding(.vertical, 6)
                                                        .background(Color.cyan)
                                                        .cornerRadius(8)
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityLabel("Confirm reminder creation")
                                                
                                                Button(action: {
                                                    chatService.cancelReminder(messageId: message.id)
                                                }) {
                                                    Text("Cancel")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(.white.opacity(0.7))
                                                        .padding(.horizontal, 14)
                                                        .padding(.vertical, 6)
                                                        .background(Color.white.opacity(0.08))
                                                        .cornerRadius(8)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                                        )
                                                }
                                                .buttonStyle(.plain)
                                                .accessibilityLabel("Cancel reminder creation")
                                            }
                                            .padding(.top, 4)
                                        }
                                        .padding(14)
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                        .frame(maxWidth: 320, alignment: .leading)
                                        .id(message.id)
                                        
                                        Spacer()
                                    } else {
                                        if message.sender == .user {
                                            Spacer()
                                        }
                                        
                                        VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 4) {
                                            Text(message.text)
                                                .font(.system(size: 13, weight: .regular))
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 14)
                                                .background(
                                                    Group {
                                                        if message.sender == .user {
                                                            LinearGradient(
                                                                colors: [Color.blue.opacity(0.85), Color.cyan.opacity(0.85)],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        } else {
                                                            Color.white.opacity(0.06)
                                                        }
                                                    }
                                                )
                                                .cornerRadius(16)
                                                .foregroundColor(.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(
                                                            message.sender == .user 
                                                                ? Color.blue.opacity(0.2) 
                                                                : Color.white.opacity(0.08), 
                                                            lineWidth: 1
                                                        )
                                                )
                                                .shadow(color: message.sender == .user ? Color.blue.opacity(0.15) : Color.clear, radius: 4, x: 0, y: 2)
                                                .textSelection(.enabled)
                                            
                                            // Small local timestamp
                                            Text(message.timestamp, style: .time)
                                                .font(.system(size: 9))
                                                .foregroundColor(.white.opacity(0.4))
                                                .padding(.horizontal, 4)
                                        }
                                        .frame(maxWidth: 320, alignment: message.sender == .user ? .trailing : .leading)
                                        .id(message.id)
                                        
                                        if message.sender == .assistant {
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            
                            // Inline processing indicator with "Orbit is thinking..." text
                            if chatService.isProcessing && chatService.statusLabel == "Thinking..." {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                    
                                    Text("Orbit is thinking...")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(12)
                                .padding(.bottom, 8)
                                .id("thinking_indicator")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: chatService.messages) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: chatService.isProcessing) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .padding(.bottom, 12)
                
                // Bottom Input Panel (Composer pinned safely at the bottom)
                HStack(spacing: 10) {
                    // Text Field Container
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.white.opacity(0.3))
                        
                        TextField("Ask Orbit anything...", text: $inputText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .font(.system(size: 13))
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                submitInput()
                            }
                            .accessibilityLabel("Ask Orbit Anything Typing Bar")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(isInputHovered ? 0.08 : 0.04))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(isInputHovered ? 0.15 : 0.08), lineWidth: 1)
                    )
                    .onHover { hovering in
                        isInputHovered = hovering
                    }
                    
                    // Send Button
                    Button(action: {
                        submitInput()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(inputText.isEmpty ? .white.opacity(0.3) : .black)
                            .frame(width: 34, height: 34)
                            .background(inputText.isEmpty ? Color.white.opacity(0.04) : Color.cyan)
                            .cornerRadius(12)
                            .shadow(color: inputText.isEmpty ? .clear : Color.cyan.opacity(0.45), radius: 8, x: 0, y: 0)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty)
                    .accessibilityLabel("Send message")
                    .onHover { hovering in
                        isSendHovered = hovering
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .padding(.vertical, 16)
            
            // Sidebar Recent Commands Panel
            RecentCommandsPanel()
        }
        .padding(18)
        .alert(isPresented: $speechService.showPermissionAlert) {
            Alert(
                title: Text("Permissions Required"),
                message: Text(speechService.errorMessage ?? "Please enable Microphone and Speech Recognition permissions for Orbit in System Settings."),
                primaryButton: .default(Text("Open Settings")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    } else if let fallbackUrl = URL(string: "x-apple.systempreferences:") {
                        NSWorkspace.shared.open(fallbackUrl)
                    }
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
        .onChange(of: chatService.focusInputTrigger) { _ in
            isTextFieldFocused = true
        }
        .onChange(of: speechService.recognizedText) { newValue in
            if speechService.isListening {
                inputText = newValue
            }
        }
        .onChange(of: speechService.isListening) { newValue in
            if !newValue {
                inputText = ""
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            isTextFieldFocused = true // Automatically focus text field when app opens
        }
    }
    
    private func submitInput() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        chatService.sendMessage(inputText)
        inputText = ""
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if chatService.isProcessing && chatService.statusLabel == "Thinking..." {
                proxy.scrollTo("thinking_indicator", anchor: .bottom)
            } else if let lastMessage = chatService.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}
