import SwiftUI

struct RecentCommandsPanel: View {
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var commandService = CommandService.shared
    @State private var hoveredCommandID: UUID? = nil
    @State private var showClearAlert = false
    @State private var selectedTab = 0 // 0 = Recent, 1 = Help
    @State private var hoveredHelpIndex: Int? = nil
    
    private struct HelpCommandItem {
        let title: String
        let desc: String
        let icon: String
    }
    
    private let helpCommands = [
        HelpCommandItem(title: "Hello", desc: "Greet the Orbit assistant", icon: "hand.wave.fill"),
        HelpCommandItem(title: "Open Safari", desc: "Launch Safari browser", icon: "safari.fill"),
        HelpCommandItem(title: "What time is it?", desc: "Check current local time", icon: "clock.fill"),
        HelpCommandItem(title: "Remind me in 10 minutes to drink water", desc: "Schedule a task reminder", icon: "bell.fill"),
        HelpCommandItem(title: "Give me my daily briefing", desc: "Hear calendar briefings", icon: "calendar.badge.clock")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Section
            HStack {
                Text(selectedTab == 0 ? "Recent commands" : "Help & Examples")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                if selectedTab == 0 && !commandService.commands.isEmpty {
                    Button(action: {
                        showClearAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .help("Clear command history")
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Tab Switcher Segmented Picker
            HStack(spacing: 0) {
                Button(action: { selectedTab = 0 }) {
                    VStack(spacing: 6) {
                        Text("Recent")
                            .font(.system(size: 12, weight: selectedTab == 0 ? .bold : .medium))
                            .foregroundColor(selectedTab == 0 ? .white : .white.opacity(0.5))
                        
                        Rectangle()
                            .fill(selectedTab == 0 ? Color.cyan : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                
                Button(action: { selectedTab = 1 }) {
                    VStack(spacing: 6) {
                        Text("Help")
                            .font(.system(size: 12, weight: selectedTab == 1 ? .bold : .medium))
                            .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.5))
                        
                        Rectangle()
                            .fill(selectedTab == 1 ? Color.cyan : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            // Content Switcher
            if selectedTab == 0 {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        let grouped = Dictionary(grouping: commandService.commands, by: { $0.category })
                        
                        ForEach(grouped.keys.sorted(), id: \.self) { category in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(category.uppercased())
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.horizontal)
                                
                                ForEach(grouped[category] ?? []) { command in
                                    Button(action: {
                                        chatService.sendMessage(command.title)
                                    }) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.cyan.opacity(0.12))
                                                    .frame(width: 28, height: 28)
                                                Image(systemName: command.iconName)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.cyan)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(command.title)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.85))
                                                Text(command.description)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.white.opacity(0.5))
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(hoveredCommandID == command.id ? Color.white.opacity(0.08) : Color.clear)
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { isHovered in
                                        withAnimation(.easeOut(duration: 0.15)) {
                                            hoveredCommandID = isHovered ? command.id : nil
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("TRY THESE COMMANDS")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal)
                        
                        ForEach(0..<helpCommands.count, id: \.self) { index in
                            let item = helpCommands[index]
                            Button(action: {
                                chatService.sendMessage(item.title)
                            }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.cyan.opacity(0.12))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: item.icon)
                                            .font(.system(size: 14))
                                            .foregroundColor(.cyan)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("“\(item.title)”")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.95))
                                            .multilineTextAlignment(.leading)
                                        Text(item.desc)
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(hoveredHelpIndex == index ? Color.white.opacity(0.08) : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovered in
                                withAnimation(.easeOut(duration: 0.15)) {
                                    hoveredHelpIndex = isHovered ? index : nil
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .alert(isPresented: $showClearAlert) {
            Alert(
                title: Text("Clear History"),
                message: Text("Are you sure you want to clear your command history?"),
                primaryButton: .destructive(Text("Clear")) {
                    commandService.clearHistory()
                },
                secondaryButton: .cancel()
            )
        }
        .frame(width: 250)
        .glassBackground(cornerRadius: 16, material: .hudWindow, blendingMode: .withinWindow)
    }
}
