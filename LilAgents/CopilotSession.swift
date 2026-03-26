import Foundation

class CopilotSession: BaseAgentSession {
    private var isFirstTurn = true
    private var useJsonOutput = true
    private var collectedPlainText = ""

    override func findBinaryName() -> String { "copilot" }

    override func findBinaryFallbackPaths(home: String) -> [String] {
        [
            "\(home)/.local/bin/copilot",
            "\(home)/.npm-global/bin/copilot",
            "/usr/local/bin/copilot",
            "/opt/homebrew/bin/copilot"
        ]
    }

    override func findBinaryErrorKey() -> String { "error.copilot.not_found" }

    override func installInstructions() -> String { AgentProvider.copilot.installInstructions }

    override func configureProcess(_ proc: Process) {
        proc.environment = ShellEnvironment.processEnvironment(extraPaths: [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".npm-global/bin").path
        ])
    }

    override func postProcessLaunch() {
        isFirstTurn = false
    }

    override func buildArguments(message: String, resuming: Bool) -> [String] {
        var args = ["-p", message]
        if resuming {
            args.insert("--continue", at: 0)
        }
        if useJsonOutput {
            args.append(contentsOf: ["--output-format", "json"])
        } else {
            args.append("-s")
        }
        args.append("--allow-all")
        return args
    }

    override func launchFailedMessage(error: Error) -> String {
        NSLocalizedString("error.copilot.launch_failed", comment: "") + ": \(error.localizedDescription)"
    }

    override func send(message: String) {
        guard isRunning, let binaryPath = binaryPath else { return }
        isBusy = true
        history.append(AgentMessage(role: .user, text: message))
        lineBuffer = ""
        collectedPlainText = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = buildArguments(message: message, resuming: history.count > 1)
        proc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        configureProcess(proc)

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        proc.terminationHandler = createTerminationHandler()

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    if self?.useJsonOutput == true {
                        self?.processOutput(text)
                    } else {
                        self?.collectedPlainText += text
                    }
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.onError?(text)
                }
            }
        }

        do {
            try proc.run()
            process = proc
            outputPipe = outPipe
            errorPipe = errPipe
            isFirstTurn = false
        } catch {
            isBusy = false
            let msg = launchFailedMessage(error: error)
            onError?(msg)
            history.append(AgentMessage(role: .error, text: msg))
        }
    }

    override func createTerminationHandler() -> (Process) -> Void {
        return { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.process = nil
                if !self.lineBuffer.isEmpty {
                    self.parseLine(self.lineBuffer)
                    self.lineBuffer = ""
                }
                if self.isBusy {
                    self.isBusy = false
                    self.onTurnComplete?()
                }
            }
        }
    }

    // MARK: - JSONL Parsing

    override func parseLine(_ line: String) {
        guard let rawData = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: rawData) as? [String: Any] else {
            if history.count <= 1 {
                useJsonOutput = false
                let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    history.append(AgentMessage(role: .assistant, text: text))
                    onText?(text)
                }
            }
            return
        }

        if json["ephemeral"] as? Bool == true {
            let type = json["type"] as? String ?? ""
            if type == "assistant.message_delta",
               let data = json["data"] as? [String: Any],
               let delta = data["deltaContent"] as? String, !delta.isEmpty {
                onText?(delta)
            }
            return
        }

        let type = json["type"] as? String ?? ""
        let data = json["data"] as? [String: Any] ?? [:]

        switch type {
        case "assistant.message":
            let content = data["content"] as? String ?? ""
            if !content.isEmpty {
                history.append(AgentMessage(role: .assistant, text: content))
            }

        case "assistant.turn_end":
            isBusy = false
            onTurnComplete?()

        case "result":
            isBusy = false
            onTurnComplete?()

        case "assistant.tool_call":
            let toolName = data["name"] as? String ?? data["tool"] as? String ?? "Tool"
            let input = data["input"] as? [String: Any] ?? data["arguments"] as? [String: Any] ?? [:]
            let command = input["command"] as? String ?? ""
            let displayName = command.isEmpty ? toolName : "Bash"
            let summary = command.isEmpty ? toolName : command
            history.append(AgentMessage(role: .toolUse, text: "\(displayName): \(summary)"))
            onToolUse?(displayName, input)

        case "assistant.tool_result":
            let output = data["output"] as? String ?? data["result"] as? String ?? ""
            let isError = (data["is_error"] as? Bool) ?? (data["status"] as? String == "error")
            let summary = String(output.prefix(80))
            history.append(AgentMessage(role: .toolResult, text: isError ? "ERROR: \(summary)" : summary))
            onToolResult?(summary, isError)

        case "error":
            let msg = data["message"] as? String ?? data["error"] as? String ?? NSLocalizedString("error.unknown", comment: "")
            onError?(msg)
            history.append(AgentMessage(role: .error, text: msg))

        default:
            break
        }
    }
}
