import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // SF Symbol App Icon Placeholder
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 4)
                
                Image(systemName: "circle.circle")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.top, 24)
            
            VStack(spacing: 4) {
                Text("Orbit")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Version 1.0 (Build 1)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Divider()
                .padding(.horizontal, 24)
                .background(Color.white.opacity(0.1))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Purpose")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("Orbit is a personal desktop voice assistant designed for macOS, providing quick allowlisted task automation, local daily calendar/reminder briefings, and conversational fallback via Google Gemini AI.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                            .lineSpacing(3)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Privacy Statement")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("Orbit prioritizes security and handles all operations locally. Command histories are saved only on this Mac, speech recording files are never stored, and credentials are encrypted inside the native macOS System Keychain. AI queries are sent to Google only if enabled.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.7))
                            .lineSpacing(3)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Required System Permissions")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.cyan)
                        
                        permissionRow(icon: "mic.fill", name: "Microphone Access", desc: "Used to capture voice command audio signals.")
                        permissionRow(icon: "waveform", name: "Speech Recognition", desc: "Used to convert voice command recordings into text.")
                        permissionRow(icon: "calendar", name: "Calendar Events", desc: "Used to fetch today's schedule for your briefing.")
                        permissionRow(icon: "bell.fill", name: "Task Reminders", desc: "Used to retrieve upcoming tasks and save reminders.")
                    }
                }
                .padding(.horizontal, 24)
            }
            
            Text("© 2026 Orbit Contributors. All rights reserved.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
                .padding(.bottom, 20)
        }
        .frame(width: 380, height: 440)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .withinWindow))
    }
    
    private func permissionRow(icon: String, name: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.cyan)
                .frame(width: 16)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 2)
    }
}
