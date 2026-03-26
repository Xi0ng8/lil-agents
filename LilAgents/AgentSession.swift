import Foundation

// MARK: - Provider

enum AgentProvider: String, CaseIterable {
    case claude, codex, copilot

    private static let defaultsKey = "selectedProvider"

    static var current: AgentProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? "claude"
            return AgentProvider(rawValue: raw) ?? .claude
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    var displayName: String {
        switch self {
        case .claude:  return NSLocalizedString("provider.claude", comment: "Claude provider name")
        case .codex:   return NSLocalizedString("provider.codex", comment: "Codex provider name")
        case .copilot: return NSLocalizedString("provider.copilot", comment: "Copilot provider name")
        }
    }

    var inputPlaceholder: String {
        switch self {
        case .claude:  return NSLocalizedString("input.placeholder.claude", comment: "Ask Claude...")
        case .codex:   return NSLocalizedString("input.placeholder.codex", comment: "Ask Codex...")
        case .copilot: return NSLocalizedString("input.placeholder.copilot", comment: "Ask Copilot...")
        }
    }

    /// Returns provider name styled per theme format.
    func titleString(format: TitleFormat) -> String {
        switch format {
        case .uppercase:      return displayName.uppercased()
        case .lowercaseTilde: return "\(displayName.lowercased()) ~"
        case .capitalized:    return displayName
        }
    }

    var installInstructions: String {
        switch self {
        case .claude:
            return NSLocalizedString("install.instructions.claude", comment: "Claude CLI install instructions")
        case .codex:
            return NSLocalizedString("install.instructions.codex", comment: "Codex CLI install instructions")
        case .copilot:
            return NSLocalizedString("install.instructions.copilot", comment: "Copilot CLI install instructions")
        }
    }

    func createSession() -> any AgentSession {
        switch self {
        case .claude:  return ClaudeSession()
        case .codex:   return CodexSession()
        case .copilot: return CopilotSession()
        }
    }
}

// MARK: - Title Format

enum TitleFormat {
    case uppercase       // "CLAUDE"
    case lowercaseTilde  // "claude ~"
    case capitalized     // "Claude"
}

// MARK: - Message

struct AgentMessage {
    enum Role { case user, assistant, error, toolUse, toolResult }
    let role: Role
    let text: String
}

// MARK: - Session Protocol

protocol AgentSession: AnyObject {
    var isRunning: Bool { get }
    var isBusy: Bool { get }
    var history: [AgentMessage] { get }

    var onText: ((String) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    var onToolUse: ((String, [String: Any]) -> Void)? { get set }
    var onToolResult: ((String, Bool) -> Void)? { get set }
    var onSessionReady: (() -> Void)? { get set }
    var onTurnComplete: (() -> Void)? { get set }
    var onProcessExit: (() -> Void)? { get set }

    func start()
    func send(message: String)
    func terminate()
}
