import Foundation

class CodexSession: BaseAgentSession {
    private var isFirstTurn = true

    override func findBinaryName() -> String { "codex" }

    override func findBinaryFallbackPaths(home: String) -> [String] {
        [
            "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex"
        ]
    }

    override func findBinaryErrorKey() -> String { "error.codex.not_found" }

    override func installInstructions() -> String { AgentProvider.codex.installInstructions }

    override func configureProcess(_ proc: Process) {
        proc.environment = ShellEnvironment.processEnvironment(extraPaths: [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".npm-global/bin").path
        ])
    }

    override func postProcessLaunch() {
        isFirstTurn = false
    }

    override func buildArguments(message: String, resuming: Bool) -> [String] {
        if isFirstTurn {
            return ["exec", "--json", "--full-auto", "--skip-git-repo-check", message]
        } else {
            return ["exec", "resume", "--last", "--json", "--full-auto", "--skip-git-repo-check", message]
        }
    }

    override func launchFailedMessage(error: Error) -> String {
        NSLocalizedString("error.codex.launch_failed", comment: "") + ": \(error.localizedDescription)"
    }

    // MARK: - JSONL Parsing

    override func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let type = json["type"] as? String ?? ""

        switch type {
        case "thread.started":
            break

        case "item.started":
            if let item = json["item"] as? [String: Any] {
                let itemType = item["type"] as? String ?? ""
                if itemType == "command_execution" {
                    let command = item["command"] as? String ?? ""
                    history.append(AgentMessage(role: .toolUse, text: "Bash: \(command)"))
                    onToolUse?("Bash", ["command": command])
                }
            }

        case "item.completed":
            if let item = json["item"] as? [String: Any] {
                let itemType = item["type"] as? String ?? ""
                switch itemType {
                case "agent_message":
                    let text = item["text"] as? String ?? ""
                    if !text.isEmpty {
                        history.append(AgentMessage(role: .assistant, text: text))
                        onText?(text)
                    }
                case "command_execution":
                    let status = item["status"] as? String ?? ""
                    let command = item["command"] as? String ?? ""
                    let isError = status == "failed"
                    let summary = command.isEmpty ? status : String(command.prefix(80))
                    history.append(AgentMessage(role: .toolResult, text: isError ? "ERROR: \(summary)" : summary))
                    onToolResult?(summary, isError)
                case "file_change":
                    let path = item["file"] as? String ?? item["path"] as? String ?? "file"
                    history.append(AgentMessage(role: .toolUse, text: "FileChange: \(path)"))
                    onToolUse?("FileChange", ["file_path": path])
                    history.append(AgentMessage(role: .toolResult, text: path))
                    onToolResult?(path, false)
                default:
                    break
                }
            }

        case "turn.completed":
            isBusy = false
            onTurnComplete?()

        case "turn.failed":
            isBusy = false
            let msg = json["message"] as? String ?? NSLocalizedString("error.codex.turn_failed", comment: "")
            onError?(msg)
            history.append(AgentMessage(role: .error, text: msg))
            onTurnComplete?()

        case "error":
            let msg = json["message"] as? String ?? json["error"] as? String ?? NSLocalizedString("error.unknown", comment: "")
            onError?(msg)
            history.append(AgentMessage(role: .error, text: msg))

        default:
            break
        }
    }
}
