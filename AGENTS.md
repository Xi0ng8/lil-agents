# AGENTS.md — lil agents

## Project Overview

**lil agents** is a macOS menu bar app that displays animated characters (Bruce & Jazz) walking above the Dock. Clicking a character opens a popover AI terminal supporting Claude Code, OpenAI Codex, and GitHub Copilot CLIs.

- **Platform:** macOS Sonoma 14.0+
- **Language:** Swift 5.0
- **UI Framework:** AppKit + SwiftUI (SwiftUI for `App` entry only; all views are AppKit)
- **External Dependencies:** [Sparkle](https://github.com/sparkle-project/Sparkle) v2.6.0+ (auto-updates, via SPM)
- **No test target exists** in the project

## Build & Run

Open in Xcode and press Cmd+R, or use the command line:

```bash
# Build for Debug
xcodebuild -project lil-agents.xcodeproj -scheme LilAgents -configuration Debug build

# Build for Release
xcodebuild -project lil-agents.xcodeproj -scheme LilAgents -configuration Release build

# Clean build folder
xcodebuild -project lil-agents.xcodeproj -scheme LilAgents clean
```

The built app is output to `build/Debug/` or `build/Release/`. There are **no tests, no lint, no typecheck commands** — the project has no test target and no SwiftLint or similar tool configured.

## Project Structure

```
lil-agents/
├── LilAgents/
│   ├── LilAgentsApp.swift          # App entry point, AppDelegate, menu bar setup
│   ├── LilAgentsController.swift   # Main controller, dock geometry, display link
│   ├── WalkerCharacter.swift       # Character video, popover, thinking bubbles, sessions
│   ├── CharacterContentView.swift  # Alpha-based hit testing for character clicks
│   ├── TerminalView.swift          # NSTextView-based terminal with markdown rendering
│   ├── PopoverTheme.swift          # Theme definitions (Midnight, Peach, Cloud, Moss)
│   ├── AgentSession.swift          # AgentSession protocol + AgentProvider enum
│   ├── ClaudeSession.swift         # Claude CLI integration
│   ├── CodexSession.swift          # OpenAI Codex CLI integration
│   ├── CopilotSession.swift        # GitHub Copilot CLI integration
│   ├── ShellEnvironment.swift      # Shell PATH resolution and binary lookup
│   ├── Info.plist                  # App metadata, Sparkle config
│   ├── LilAgents.entitlements      # App sandbox disabled
│   ├── Assets.xcassets/            # App icon, menu bar icon
│   ├── Sounds/                     # Ping sound effects (mp3/m4a)
│   └── walk-*.mov                  # Character walk animations (HEVC, transparent)
├── lil-agents.xcodeproj/
├── README.md
├── LICENSE                         # MIT
└── appcast.xml                     # Sparkle update feed
```

## Code Style

### Naming Conventions
- **Types:** PascalCase (`WalkerCharacter`, `AgentSession`, `PopoverTheme`)
- **Properties/methods:** camelCase (`currentProvider`, `startWalking()`)
- **Constants:** camelCase, no `k` prefix
- **UserDefaults keys:** camelCase string literals (`"hasCompletedOnboarding"`, `"selectedProvider"`)
- **File names:** Match primary type name exactly

### Imports
- Import only what each file needs: `SwiftUI`, `AppKit`, `AVFoundation`, `Foundation`
- Do not use `@testable import` (no test target)

### Architecture Patterns
- **No SwiftUI views** — all UI is pure AppKit (`NSWindow`, `NSTextView`, `NSPopover`)
- The only SwiftUI is the `@main App` struct with `@NSApplicationDelegateAdaptor`
- Controllers are plain classes (no `ObservableObject`), managed via strong references in `AppDelegate`
- Use `CVDisplayLink` for animation timing, not `Timer`
- Protocols define agent session contracts (`AgentSession` protocol with closure callbacks)

### Error Handling
- Errors are passed via optional closure callbacks, not `throws`
- Pattern: `onError: ((String) -> Void)?`
- CLI-not-found errors show install instructions as user-facing strings

### Memory Management
- Use `[weak self]` in closures and event monitors
- Use `Unmanaged.passUnretained(self)` inside CVDisplayLink callbacks (performance critical)
- Store `NSEvent.addGlobalMonitorForEvents` monitors and remove them on cleanup

### Concurrency
- Use `DispatchQueue.main.async` for all UI updates from background threads
- No async/await — uses Process/pipe-based subprocess execution
- Character animation updates run on the CVDisplayLink thread, dispatch UI to main

### Strings & i18n
- All user-facing strings are hardcoded literals (no NSLocalizedString yet)
- Thinking phrases, completion phrases, onboarding text, menu items, error messages — all in `WalkerCharacter.swift` and `LilAgentsApp.swift`
- Provider names ("Claude", "Codex", "Copilot") are defined in `AgentSession.swift`

### Formatting
- 4-space indentation
- Opening braces on same line: `if condition {`
- Trailing closures preferred
- No enforced formatter (no SwiftFormat/SwiftLint config)

## Key Implementation Details

- **Dock detection:** Reads macOS Dock tile size from `com.apple.dock` preferences via `UserDefaults(suiteName:)`
- **Character positioning:** Calculates screen width minus Dock tile count to find free space
- **Video playback:** `AVPlayerLooper` with `AVQueuePlayer` for seamless looping of transparent HEVC `.mov` files
- **Popover terminal:** Custom `NSTextView` subclass with markdown-to-NSAttributedString parsing using regex
- **Sparkle integration:** `SPUStandardUpdaterController` owned by `AppDelegate`; menu items for "Check for Updates"
