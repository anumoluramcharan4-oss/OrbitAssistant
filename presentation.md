# Orbit Voice Assistant — Project Presentation Guide

This guide contains the project presentation script and sample Q&A sheets to help prepare for your college project demonstration.

---

## Part 1: Presentation Script

> [!NOTE]
> *Suggested Duration: 3-5 Minutes. Speak clearly, pause for transitions, and use the demo script in the README to show the actions live as you describe them.*

**[Introduction]**
"Good morning/afternoon. My project is called **Orbit**, a Jarvis-inspired personal desktop assistant built natively for macOS."

**[App Purpose & Capability]**
"Orbit lets a user type or speak commands. It can answer simple questions such as the current time and date, open approved Mac applications and folders, search the web, and respond to general questions using Gemini AI."

**[Architecture & Technologies]**
"I built the user interface entirely using **SwiftUI**, which is Apple’s modern declarative framework for building native Mac interfaces. For voice capabilities, I integrated the native Apple **Speech framework** for converting microphone input into text, and the **AVFoundation framework** to synthesize Orbit’s spoken replies."

**[Safety Design]**
"For safety, Orbit does not run arbitrary Terminal commands or perform destructive actions like deleting files. Instead, it routes inputs through a strict local allowlist: only safe actions like opening Apple Calendar, Finder, the Downloads/Documents folders, or approved websites are supported."

**[Privacy and Configuration]**
"The application respects user privacy: there is no login page, no user account system, and no remote cloud database. Command history is saved strictly on the user's local Mac using `UserDefaults`. If AI features are enabled, the Gemini API key is stored securely inside the native macOS System Keychain."

**[Demonstration Summary]**
"During this demonstration, I will launch Orbit from the menu bar helper, ask for the local time using voice dictation, ask it to open Calendar, query a general AI question to show the Gemini fallback, and finally show the settings overlay and the history clear controls."

**[Conclusion & Next Steps]**
"In the future, I plan to extend Orbit by adding support for setting calendar reminders/tasks, adding wider accessibility triggers, and building better natural-language offline command handling. Thank you, and I am open to any questions."

---

## Part 2: Instructor Q&A Sheet

### Core Purpose & Tech

*   **Q: What problem does Orbit solve?**  
    *   **A:** It provides a faster, hands-free, voice-friendly cockpit to perform common Mac tasks and retrieve quick answers without opening multiple application windows.
*   **Q: Why did you use SwiftUI?**  
    *   **A:** SwiftUI is Apple’s modern, declarative UI framework. It enables writing clean, state-based, and highly reusable native macOS controls with minimal boilerplate.
*   **Q: How does voice input work?**  
    *   **A:** The app requests microphone and speech-recognition permissions. Apple's Speech framework captures the microphone buffer stream in real time and converts the audio waves into transcribed text.
*   **Q: How does Orbit speak?**  
    *   **A:** It uses `AVSpeechSynthesizer` from Apple’s `AVFoundation` framework to read Orbit's text output aloud using native Siri voice models.

### Command Routing & Safety

*   **Q: How does the app understand commands?**  
    *   **A:** The query is routed to a local `CommandRouter`. It normalizes the text and checks it against static regular expression matches (e.g. matching *"open finder"* to launch Finder).
*   **Q: Why use a CommandRouter instead of allowing AI to control the Mac directly?**  
    *   **A:** It is a critical safety sandbox. By routing through a local parser, the AI cannot execute arbitrary shell commands, access protected files, or modify system settings, protecting the user from injection payloads.
*   **Q: What is the role of Gemini AI?**  
    *   **A:** Gemini answers general informational questions that fixed local commands cannot handle. It acts purely as a conversational fallback and has no direct access to system control APIs.

### Privacy & Limitations

*   **Q: How do you protect privacy?**  
    *   **A:** Orbit has no user accounts, remote databases, or tracking telemetry. Command records are saved strictly on-disk locally, voice audio recordings are never cached, and API keys are stored in the macOS Keychain.
*   **Q: What happens if the user denies microphone permissions?**  
    *   **A:** The app catches the authorization block gracefully, appends a detailed guide in the chat feed on how to authorize the app, and displays a settings redirection dialog.
*   **Q: What are the project limitations?**  
    *   **A:** The local command list is hardcoded, dictation transcribers depend on system-level availability, and AI questions require an internet connection and a configured API key.
*   **Q: How would you improve it in the future?**  
    *   **A:** I would add support for reminders, calendar entries, wider folder controls, offline local LLM models (like Apple MLX), and two-factor confirmation dialogs for sensitive system tasks.
