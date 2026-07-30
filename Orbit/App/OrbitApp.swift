import SwiftUI
import AppKit

class AboutWindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        OrbitApp.aboutWindow = nil
    }
}

@main
struct OrbitApp: App {
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var commandService = CommandService.shared
    
    static var aboutWindow: NSWindow?
    static let aboutDelegate = AboutWindowDelegate()
    
    init() {
        // Register Carbon global hotkey (Command + Shift + Space)
        HotKeyManager.shared.register {
            OrbitApp.openOrbitWindow()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(width: 820, height: 560)
                .background(
                    VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                        .ignoresSafeArea()
                )
                .background(WindowAccessor { window in
                    if let window = window {
                        window.isOpaque = false
                        window.backgroundColor = .clear
                        window.titlebarAppearsTransparent = true
                        window.titleVisibility = .hidden
                        window.styleMask.insert(.fullSizeContentView)
                    }
                })
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        // Native macOS Menu Bar helper (macOS 13.0+)
        MenuBarExtra("Orbit", systemImage: "circle.circle") {
            Button("Open Orbit") {
                OrbitApp.openOrbitWindow()
            }
            .keyboardShortcut("o", modifiers: [.command])
            
            Button("About Orbit...") {
                OrbitApp.openAboutWindow()
            }
            
            Divider()
            
            Text("Status: \(chatService.statusLabel)")
            
            Divider()
            
            Text("Recent Commands:")
            
            ForEach(commandService.commands.prefix(5)) { command in
                Button(command.title) {
                    OrbitApp.openOrbitWindow()
                    chatService.sendMessage(command.title)
                }
            }
            
            Divider()
            
            Button("Quit Orbit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
    
    static func openOrbitWindow() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.titlebarAppearsTransparent }) {
                window.makeKeyAndOrderFront(nil)
            }
            ChatService.shared.focusInput()
        }
    }
    
    static func openAboutWindow() {
        DispatchQueue.main.async {
            if let existing = aboutWindow {
                existing.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
            
            let view = AboutView()
            let hostingController = NSHostingController(rootView: view)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 440),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "About Orbit"
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            window.delegate = aboutDelegate
            
            aboutWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var onChange: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onChange(view.window)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onChange(nsView.window)
        }
    }
}
