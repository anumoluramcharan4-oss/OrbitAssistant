# Orbit — Personal Mac Assistant

Orbit is a polished, native macOS desktop assistant built using SwiftUI. Designed as a high-fidelity college project demonstration, it mimics a futuristic AI hud overlay, combining fast local allowlisted commands with general conversational AI powered by Google's Gemini API.

---

## Main Features

1.  **Vibrant HUD Control Center**
    *   Frosted glass backdrop visual layouts conforming to native macOS window hierarchies.
    *   Large animated central microphone button with custom glows (blue for ready, pulsing waves for listening, disabled grey circle with a progress spinner while processing).
2.  **Allowlisted Local Commands**
    *   Fast, local execution for basic greeting, system time/date queries, directory navigation, Google searches, and application launching without querying the cloud.
3.  **Configurable Gemini AI Conversational Support**
    *   Integrates Google Generative Language REST APIs to answer general questions (e.g., *"explain photosynthesis"* or *"what is the height of mount everest"*).
    *   Supports customizable model names (defaulting to `gemini-3.6-flash`).
    *   Injects system instructions: *"Orbit is a concise, helpful Mac assistant. It must not claim it performed a Mac action unless MacActionService actually performed it."*
4.  **Secure macOS Keychain Integration**
    *   Saves the user's custom Gemini API key directly to the native macOS System Keychain using generic password wrappers (`kSecClassGenericPassword`), ensuring the credential is never written to source code, logs, or `UserDefaults`.
5.  **Menu-Bar Assistant & Global Hotkeys**
    *   Custom `MenuBarExtra` scene providing access to app status, the 5 most recent commands, and instant launchers.
    *   System-wide global hotkey (`Command + Shift + Space`) using the privacy-compliant Carbon framework to bring Orbit to the foreground and automatically focus the typing bar.
6.  **Interactive In-App Help & Example Commands**
    *   Adds a dedicated **Help** segment to the right sidebar panel containing standard template commands.
    *   Includes click-to-run buttons for allowlisted actions such as *"Hello"*, *"Open Safari"*, *"What time is it?"*, *"Remind me in 10 minutes to drink water"*, and *"Give me my daily briefing"*.
    *   All technical logs and debugging components are cleanly hidden from view, providing a polished user experience.

---

## Technologies Used

*   **SwiftUI & AppKit**: User interface panels, frosted window accessories, and application scenes.
*   **Speech Framework**: transcribing live micro-audio streams to speech text.
*   **AVFoundation (`AVAudioEngine`, `AVSpeechSynthesizer`)**: Recording input bus taps, synthesising voice outputs for dictated replies.
*   **macOS System Keychain (Security)**: Cryptographically saving API credentials.
*   **UserDefaults**: Storing lightweight settings toggles and history logs locally.
*   **URLSession**: Standard, zero-dependency networking for REST API requests.

---

## Privacy and Safety Design

*   **No Arbitrary Command Execution**: Orbit is locked down. It does not compile shell task runs, execute Terminal scripts, or perform destructive file operations (moving, deleting, renaming).
*   **Strict Action Allowlist**: App opening and folder navigation are limited strictly to pre-approved standard apps (Safari, Chrome, Notes, Calendar, Spotify) and directories (Home, Downloads, Documents).
*   **Local Persistence**: All command logs and settings are stored entirely on the local device. No telemetry, user accounts, cloud databases, tracking, or analytics are incorporated.

---

## Required Permissions

To support voice dictation, the app plist declares:
*   `NSMicrophoneUsageDescription`: *"Orbit uses your microphone to listen to voice commands."*
*   `NSSpeechRecognitionUsageDescription`: *"Orbit converts your voice commands into text."*

If these permissions are denied, Orbit displays an inline warning card in the chat view with directions, alongside a Settings redirect dialog.

---

## How to Run the Project

### Prerequisites
- macOS 13.0 or later.
- Xcode 14.0 or later.
- `XcodeGen` installed (run `brew install xcodegen` if missing).

### Compilation and Launch
1.  Open Terminal in the repository root directory.
2.  Generate the Xcode project:
    ```bash
    xcodegen generate
    ```
3.  Open the generated project:
    ```bash
    open Orbit.xcodeproj
    ```
4.  In Xcode, select the active scheme `Orbit` and select **Product > Run** (or press `Cmd + R`) to compile and launch.
5.  To run unit tests, select **Product > Test** (or press `Cmd + U`).

### Exporting for Local Release (Archive)
To build a standalone production release of Orbit and install it in your macOS Applications folder:
1. Open the generated `Orbit.xcodeproj` in Xcode.
2. In the top schema bar, select **Any Mac** or **My Mac** as the target build destination.
3. Choose **Product > Scheme > Edit Scheme...**, verify the **Run** and **Archive** configurations are set to **Release**, and close the dialog.
4. Select **Product > Archive** from the main menu. Xcode will perform a clean, optimized release build.
5. Once the Xcode Organizer window appears, select your latest archive and click **Distribute App**.
6. Select the **Copy App** or **Direct Distribution** option to export the standalone `Orbit.app` package.
7. Drag the exported `Orbit.app` file into your Mac's `/Applications` directory to run the assistant system-wide.

---

## Known Limitations

*   **App Sandboxing**: File systems are subject to sandbox container rules, restricting folder openings to public user folders like Documents and Downloads.
*   **Hardware limitations**: Requires an active microphone and internet connectivity for the speech transcribers and Gemini AI endpoints.

---

## Future Improvements

*   **On-Device Models**: Integrate Apple MLX or Llama.cpp to process general questions locally without cloud requests.
*   **Dynamic Actions**: Implement a secure user-configurable permission map to link custom shell scripts to specific trigger keywords.

---

## Instructor Demonstration Script

To perform a clean demonstration for your project evaluation, follow these steps:

1.  **Launch & Focus**
    *   Open Orbit. Verify the blinking cursor is automatically focused inside the text input at the bottom.
    *   Press the `Cmd + Shift + Space` hotkey combinations from another application to verify Orbit pops into focus immediately.
2.  **Voice Local Command**
    *   Click the central blue microphone button. Verify the status indicator turns red and reads **Listening...**, with rings expanding.
    *   Say: *"What time is it?"*
    *   Click the microphone button again. Verify that the button switches to a loading spinner and Orbit speaks the time response.
3.  **Allowlisted Application Launcher**
    *   Type *"open calendar"* in the input bar and press **Return**.
    *   Verify Orbit replies *"Opening Calendar."* and launches the macOS Calendar application.
4.  **AI Question Fallback**
    *   Type *"explain spacetime in one sentence"* and hit **Return**.
    *   Verify Orbit prints the message: *"Add a Gemini API key in Settings to enable AI answers."*
    *   Click the **Gear icon** in the top header to open Settings.
    *   Paste your Gemini API key in the secure input, click **Save Key Securely**, and verify the green status indicator.
    *   Close Settings. Re-submit *"explain spacetime in one sentence"*.
    *   Verify the loader says **Orbit is thinking...** and returns a real Gemini response.
5.  **Settings, History Wiping & Interactive Help**
    *   Verify the right sidebar panel displays the executed command history under the **Recent** tab.
    *   Switch the sidebar selector to the **Help** tab. Click the example command: *“Remind me in 10 minutes to drink water”*. Confirm that a reminder dialog is successfully presented, and then click **Confirm** to schedule it.
    *   Click the **Gear icon** to open Settings. Click **Clear Command History**.
    *   Confirm the alert prompt and click **Clear**. Verify that both the sidebar commands and the persisted cache are wiped.
