import Foundation
import Speech
import AVFoundation
import CoreAudio

class SpeechService: ObservableObject {
    static let shared = SpeechService()
    
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var errorMessage: String? = nil
    @Published var showPermissionAlert = false
    
    // Diagnostic Properties
    @Published var micPermissionStatus: String = "Unknown"
    @Published var speechPermissionStatus: String = "Unknown"
    @Published var recognizerAvailable: Bool = false
    @Published var inputNodeSampleRate: Double = 0.0
    @Published var audioBufferCount: Int = 0
    @Published var micLevel: Float = 0.0
    @Published var debugLogs: [String] = []
    @Published var selectedInputDeviceName: String = "Unknown"
    
    var onTranscriptionComplete: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    var isAttemptingToListen: Bool {
        return audioEngine.isRunning
    }
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private var isStartingRecognition = false
    private var isTapInstalled = false
    
    private var silenceTimer: Timer?
    private var silenceDuration: TimeInterval = 0.0
    
    private init() {}
    
    func logDebug(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let formatted = "[\(timestamp)] \(message)"
        DispatchQueue.main.async {
            self.debugLogs.append(formatted)
            if self.debugLogs.count > 50 {
                self.debugLogs.removeFirst()
            }
        }
        print("Orbit Speech Debug: \(message)")
    }
    
    // Checks permissions sequentially and triggers completion on main thread.
    // Explicitly avoids setting any listening flags until both are authorized.
    func checkPermissions(completion: @escaping (Bool) -> Void) {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        let micStatusStr: String
        switch micStatus {
        case .authorized: micStatusStr = "Authorized"
        case .denied: micStatusStr = "Denied"
        case .restricted: micStatusStr = "Restricted"
        case .notDetermined: micStatusStr = "Not Determined"
        @unknown default: micStatusStr = "Unknown"
        }
        
        let speechStatusStr: String
        switch speechStatus {
        case .authorized: speechStatusStr = "Authorized"
        case .denied: speechStatusStr = "Denied"
        case .restricted: speechStatusStr = "Restricted"
        case .notDetermined: speechStatusStr = "Not Determined"
        @unknown default: speechStatusStr = "Unknown"
        }
        
        DispatchQueue.main.async {
            self.micPermissionStatus = micStatusStr
            self.speechPermissionStatus = speechStatusStr
        }
        
        updateInputDeviceName()
        
        logDebug("Microphone permission status: \(micStatusStr)")
        logDebug("Speech-recognition permission status: \(speechStatusStr)")
        
        if speechStatus == .authorized && micStatus == .authorized {
            completion(true)
            return
        }
        
        if speechStatus == .denied || speechStatus == .restricted {
            DispatchQueue.main.async {
                self.errorMessage = "Speech Recognition permission is required."
                self.isListening = false
            }
            logDebug("Exact error: Speech recognition permission is denied or restricted.")
            completion(false)
            return
        }
        
        if micStatus == .denied || micStatus == .restricted {
            DispatchQueue.main.async {
                self.errorMessage = "Microphone permission is required."
                self.isListening = false
            }
            logDebug("Exact error: Microphone permission is denied or restricted.")
            completion(false)
            return
        }
        
        // Asynchronously request authorization sequentially
        SFSpeechRecognizer.requestAuthorization { [weak self] speechAuthStatus in
            guard let self = self else { return }
            
            let statusStr: String
            switch speechAuthStatus {
            case .authorized: statusStr = "Authorized"
            case .denied: statusStr = "Denied"
            case .restricted: statusStr = "Restricted"
            case .notDetermined: statusStr = "Not Determined"
            @unknown default: statusStr = "Unknown"
            }
            
            DispatchQueue.main.async {
                self.speechPermissionStatus = statusStr
            }
            self.logDebug("Speech authorization updated to: \(statusStr)")
            
            if speechAuthStatus == .authorized {
                AVCaptureDevice.requestAccess(for: .audio) { micGranted in
                    let micGrantedStr = micGranted ? "Authorized" : "Denied"
                    DispatchQueue.main.async {
                        self.micPermissionStatus = micGrantedStr
                        if micGranted {
                            self.logDebug("Microphone access granted by user.")
                            completion(true)
                        } else {
                            self.errorMessage = "Microphone permission is required."
                            self.isListening = false
                            self.logDebug("Exact error: Microphone access denied by user.")
                            completion(false)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Speech Recognition permission is required."
                    self.isListening = false
                }
                self.logDebug("Exact error: Speech recognition access denied by user.")
                completion(false)
            }
        }
    }
    
    // Helper to query the current active input device using CoreAudio
    func updateInputDeviceName() {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: 0
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        
        guard status == noErr else {
            DispatchQueue.main.async {
                self.selectedInputDeviceName = "Unknown Device"
            }
            return
        }
        
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var deviceName: CFString = "" as CFString
        address.mSelector = kAudioDevicePropertyDeviceNameCFString
        address.mScope = kAudioObjectPropertyScopeGlobal
        address.mElement = 0
        
        let nameStatus = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &nameSize,
            &deviceName
        )
        
        DispatchQueue.main.async {
            if nameStatus == noErr {
                self.selectedInputDeviceName = deviceName as String
            } else {
                self.selectedInputDeviceName = "Unknown Device (\(deviceID))"
            }
        }
    }
    
    // Starts continuous capture of speech audio and pipes buffers to speech recognition engine
    func startRecognition() {
        guard !isStartingRecognition, !isListening, !audioEngine.isRunning, !isTapInstalled else { return }
        isStartingRecognition = true
        defer {
            isStartingRecognition = false
        }
        
        // Silence any ongoing speech output
        stopSpeaking()
        
        // Reset state
        DispatchQueue.main.async {
            self.errorMessage = nil
            self.recognizedText = ""
            self.audioBufferCount = 0
            self.micLevel = 0.0
        }
        
        checkPermissions { [weak self] granted in
            guard let self = self else { return }
            if granted {
                DispatchQueue.main.async {
                    do {
                        try self.setupAndStartAudioEngine()
                    } catch {
                        self.errorMessage = error.localizedDescription
                        self.isListening = false
                        self.logDebug("Exact error: Audio engine setup failed: \(error.localizedDescription)")
                        self.cleanupAudio()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isListening = false
                    self.cleanupAudio()
                }
            }
        }
    }
    
    private func setupAndStartAudioEngine() throws {
        // Clear previous tasks safely
        recognitionTask?.cancel()
        recognitionTask = nil
        
        guard let speechRecognizer = speechRecognizer else {
            let errorMsg = "SFSpeechRecognizer is unavailable."
            DispatchQueue.main.async {
                self.recognizerAvailable = false
            }
            throw NSError(domain: "OrbitSpeechService", code: 3, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        let isAvail = speechRecognizer.isAvailable
        DispatchQueue.main.async {
            self.recognizerAvailable = isAvail
        }
        logDebug("speechRecognizer.isAvailable: \(isAvail)")
        
        guard isAvail else {
            let errorMsg = "SFSpeechRecognizer is unavailable."
            throw NSError(domain: "OrbitSpeechService", code: 4, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "OrbitSpeechService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create speech buffer request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        
        if isTapInstalled {
            logDebug("Tap is already installed. Skipping installation.")
            return
        }
        
        inputNode.removeTap(onBus: 0)
        audioEngine.reset()
        
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let sampleRate = inputFormat.sampleRate
        DispatchQueue.main.async {
            self.inputNodeSampleRate = sampleRate
        }
        logDebug("Input-node sample rate: \(sampleRate) Hz, channels: \(inputFormat.channelCount)")
        
        // Check hardware safety
        guard sampleRate > 0 else {
            let errorMsg = "No microphone audio detected: sample rate is zero."
            self.errorMessage = errorMsg
            self.onError?(errorMsg)
            self.isListening = false
            self.cleanupAudio()
            return
        }
        
        guard inputFormat.channelCount > 0 else {
            let errorMsg = "No microphone audio detected: channel count is zero."
            self.errorMessage = errorMsg
            self.onError?(errorMsg)
            self.isListening = false
            self.cleanupAudio()
            return
        }
        
        // Install the tap only once with nil format to prevent configuration crash
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] (buffer, _) in
            guard let self = self else { return }
            
            // Append real audio buffer
            self.recognitionRequest?.append(buffer)
            
            // Calculate float channel RMS values
            guard let channelData = buffer.floatChannelData else { return }
            let channelCount = Int(buffer.format.channelCount)
            let frameLength = Int(buffer.frameLength)
            
            var rms: Float = 0.0
            if frameLength > 0 && channelCount > 0 {
                var sum: Float = 0.0
                for channel in 0..<channelCount {
                    let samples = channelData[channel]
                    for frame in 0..<frameLength {
                        let sample = samples[frame]
                        sum += sample * sample
                    }
                }
                rms = sqrt(sum / Float(frameLength * channelCount))
            }
            
            DispatchQueue.main.async {
                if !self.isListening {
                    self.isListening = true
                    self.logDebug("Audio engine started receiving buffers. Listening state activated.")
                }
                self.micLevel = min(max(rms * 5.0, 0.0), 1.0)
                self.audioBufferCount += 1
                
                // Periodically log buffers to console (about once per second / 40 buffers)
                if self.audioBufferCount % 40 == 0 {
                    self.logDebug("Audio buffer count: \(self.audioBufferCount), Live level: \(String(format: "%.3f", self.micLevel))")
                }
            }
        }
        
        self.isTapInstalled = true
        
        audioEngine.prepare()
        try audioEngine.start()
        
        logDebug("Audio engine started successfully. Awaiting first audio buffers...")
        
        // Initialize silence timer
        self.silenceDuration = 0.0
        self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.audioEngine.isRunning else { return }
            
            if self.audioBufferCount == 0 || self.micLevel < 0.005 {
                self.silenceDuration += 1.0
                if self.silenceDuration >= 3.0 {
                    DispatchQueue.main.async {
                        self.errorMessage = "No microphone audio detected. Check Orbit microphone permission and your Mac input device."
                        self.logDebug("No audio detected for 3 seconds. Checking configuration.")
                        self.stopRecognition()
                    }
                }
            } else {
                self.silenceDuration = 0.0
            }
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            if let result = result {
                let transcript = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.recognizedText = transcript
                }
                self.logDebug("Live transcript: \"\(transcript)\" (isFinal: \(result.isFinal))")
                isFinal = result.isFinal
            }
            
            if isFinal {
                DispatchQueue.main.async {
                    self.isListening = false
                    let text = self.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        self.onTranscriptionComplete?(text)
                    } else {
                        self.errorMessage = "No speech was detected. Please try again."
                        self.onError?("No speech was detected. Please try again.")
                        self.logDebug("No speech was detected after final processing.")
                    }
                    self.cleanupAudio()
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    let nsError = error as NSError
                    self.logDebug("Exact error: \(error.localizedDescription) (code: \(nsError.code))")
                    
                    if nsError.code != 301 && nsError.code != 216 && nsError.domain != "kAFAssistantErrorDomain" {
                        self.errorMessage = error.localizedDescription
                        self.isListening = false
                        self.onError?(error.localizedDescription)
                        self.cleanupAudio()
                    } else {
                        // User cancelled or finished cleanly
                        self.isListening = false
                        self.cleanupAudio()
                    }
                }
            }
        }
    }
    
    private func cleanupAudio() {
        self.silenceTimer?.invalidate()
        self.silenceTimer = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    // Stops listening and tears down audioEngine taps, awaiting the final callback result
    func stopRecognition() {
        logDebug("Manually stopping recognition. Waiting for final callback...")
        
        self.silenceTimer?.invalidate()
        self.silenceTimer = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    // Synthesizes and speaks text using native voices
    func speak(_ text: String) {
        stopSpeaking()
        
        // Safety guard: skip speech if user turned off Spoken Voice Replies
        guard ChatService.shared.isVoiceRepliesEnabled else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        speechSynthesizer.speak(utterance)
    }
    
    // Silences active output
    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }
}
