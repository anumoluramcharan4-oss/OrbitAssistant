import Carbon
import AppKit

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var actionHandler: (() -> Void)?
    
    private init() {}
    
    // SAFETY DECISION: We register the global shortcut Command + Shift + Space.
    // Carbon's RegisterEventHotKey API is highly secure and privacy-respecting.
    // Unlike low-level CGEvent taps or accessibility keyloggers, Carbon hotkeys only notify
    // the application when the specific shortcut is pressed, preventing access to any other keystrokes.
    func register(handler: @escaping () -> Void) {
        self.actionHandler = handler
        
        // Define application event type for HotKey pressed
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // Install application event handler using a C-compatible function pointer.
        // We pass the HotKeyManager instance as userData.
        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        var handlerRef: EventHandlerRef? = nil
        
        // We call InstallEventHandler directly since the InstallApplicationEventHandler macro is unavailable in Swift
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_: EventHandlerCallRef?, _: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onHotKeyPress()
                return noErr
            },
            1,
            &eventType,
            userData,
            &handlerRef
        )
        
        if handlerStatus != noErr {
            print("Failed to install Carbon event handler: \(handlerStatus)")
            return
        }
        
        // Register standard ID signature ("ORBT")
        let hotKeyID = EventHotKeyID(signature: FourCharCode("ORBT".fourCharCodeValue), id: 1)
        
        // Carbon modifiers: cmdKey (256) | shiftKey (512) = 768
        let carbonModifiers = UInt32(768)
        let spaceKeyCode = UInt32(49) // QWERTY virtual keycode for Space
        
        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            spaceKeyCode,
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        
        if registerStatus != noErr {
            print("Failed to register global hotkey: \(registerStatus)")
        } else {
            self.hotKeyRef = ref
            print("Successfully registered Command+Shift+Space global hotkey.")
        }
    }
    
    private func onHotKeyPress() {
        DispatchQueue.main.async { [weak self] in
            self?.actionHandler?()
        }
    }
}

extension String {
    // Helper to convert a String signature to FourCharCode (UInt32) for Carbon API
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        if let data = self.data(using: .macOSRoman) {
            data.withUnsafeBytes { (rawBuffer) in
                let buffer = rawBuffer.bindMemory(to: UInt8.self)
                for i in 0..<min(data.count, 4) {
                    result = (result << 8) + FourCharCode(buffer[i])
                }
            }
        }
        return result
    }
}
