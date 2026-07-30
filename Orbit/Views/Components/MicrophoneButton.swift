import SwiftUI

struct MicrophoneButton: View {
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var speechService = SpeechService.shared
    @State private var isHovered = false
    @State private var animateWaves = false
    
    var body: some View {
        VStack(spacing: 20) {
            if !speechService.isListening {
                // Show the normal microphone button: "Start Recording"
                Button(action: {
                    chatService.toggleSpeechRecognition()
                }) {
                    ZStack {
                        // Wave 3 (static placeholder or subtle opacity)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.15), Color.cyan.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: 220, height: 220)
                            .scaleEffect(0.8)
                            .opacity(0.25)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: chatService.isProcessing
                                        ? [Color.gray.opacity(0.35), Color.gray.opacity(0.15)]
                                        : [Color.blue.opacity(0.85), Color.cyan.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                Group {
                                    if chatService.isProcessing {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                                    } else {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 34, weight: .semibold))
                                            .foregroundColor(.white)
                                            .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 2)
                                    }
                                }
                            )
                            .glassBackground(cornerRadius: 45, material: .hudWindow, blendingMode: .withinWindow)
                            .scaleEffect(isHovered && !chatService.isProcessing ? 1.05 : 1.0)
                            .shadow(
                                color: chatService.isProcessing
                                    ? Color.clear
                                    : Color.blue.opacity(isHovered ? 0.55 : 0.35),
                                radius: isHovered && !chatService.isProcessing ? 20 : 12,
                                x: 0,
                                y: 0
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(chatService.isProcessing)
                .accessibilityLabel("Start Recording")
                .onHover { hovering in
                    if !chatService.isProcessing {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isHovered = hovering
                        }
                    }
                }
            } else {
                // While recording, show the animated waves and the Stop Recording button
                VStack(spacing: 24) {
                    ZStack {
                        // Wave 3 (outermost pulse)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.15), Color.orange.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: 220, height: 220)
                            .scaleEffect((animateWaves ? 1.25 : 0.8) + CGFloat(speechService.micLevel * 0.35))
                            .opacity(animateWaves ? 0.0 : 0.25)
                        
                        // Wave 2 (middle pulse)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.25), Color.orange.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 175, height: 175)
                            .scaleEffect((animateWaves ? 1.18 : 0.85) + CGFloat(speechService.micLevel * 0.35))
                            .opacity(animateWaves ? 0.0 : 0.45)

                        // Wave 1 (innermost pulse)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.35), Color.orange.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: 130, height: 130)
                            .scaleEffect((animateWaves ? 1.12 : 0.9) + CGFloat(speechService.micLevel * 0.35))
                            .opacity(animateWaves ? 0.0 : 0.65)

                        // Center recording indicator
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.85), Color.orange.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                Image(systemName: "waveform.and.mic")
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 2)
                            )
                            .glassBackground(cornerRadius: 45, material: .hudWindow, blendingMode: .withinWindow)
                            .shadow(
                                color: Color.red.opacity(0.35),
                                radius: 12,
                                x: 0,
                                y: 0
                            )
                    }
                    
                    // Large Red Stop Recording Button
                    Button(action: {
                        chatService.toggleSpeechRecognition()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Stop Recording")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.red, Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(24)
                        .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop Recording")
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .onChange(of: speechService.isListening) { newValue in
            updateAnimationState(isListening: newValue)
        }
        .onAppear {
            updateAnimationState(isListening: speechService.isListening)
        }
    }
    
    private func updateAnimationState(isListening: Bool) {
        if isListening {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                animateWaves = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.5)) {
                animateWaves = false
            }
        }
    }
}
