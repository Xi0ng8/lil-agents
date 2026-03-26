import Foundation

class BaseAgentSession: AgentSession {
    var process: Process?
    var outputPipe: Pipe?
    var errorPipe: Pipe?
    var lineBuffer = ""
    var isRunning = false
    var isBusy = false
    var binaryPath: String?

    var onText: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onToolUse: ((String, [String: Any]) -> Void)?
    var onToolResult: ((String, Bool) -> Void)?
    var onSessionReady: (() -> Void)?
    var onTurnComplete: (() -> Void)?
    var onProcessExit: (() -> Void)?

    var history: [AgentMessage] = []

    // MARK: - Template Methods (override in subclasses)

    func findBinary() -> String? {
        fatalError("Subclasses must implement findBinary()")
    }

    func buildArguments(message: String, resuming: Bool) -> [String] {
        fatalError("Subclasses must implement buildArguments(_:resuming:)")
    }

    func parseLine(_ line: String) {
        fatalError("Subclasses must implement parseLine(_:)")
    }

    func onBinaryFound() {
        isRunning = true
        onSessionReady?()
    }

    // MARK: - AgentSession

    func start() {
        if let cached = binaryPath {
            onBinaryFound()
            return
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        ShellEnvironment.findBinary(name: findBinaryName(), fallbackPaths: findBinaryFallbackPaths(home: home)) { [weak self] path in
            guard let self = self, let path = path else {
                let msg = NSLocalizedString(self?.findBinaryErrorKey() ?? "error.unknown", comment: "") + "\n\n\(self?.installInstructions() ?? "")"
                self?.onError?(msg)
                self?.history.append(AgentMessage(role: .error, text: msg))
                return
            }
            self.binaryPath = path
            self.onBinaryFound()
        }
    }

    func send(message: String) {
        guard isRunning, let binaryPath = binaryPath else { return }
        isBusy = true
        history.append(AgentMessage(role: .user, text: message))
        lineBuffer = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = buildArguments(message: message, resuming: history.count > 1)
        proc.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        proc.environment = ShellEnvironment.processEnvironment()

        configureProcess(proc)

        setupPipes(for: proc, terminationHandler: createTerminationHandler())

        do {
            try proc.run()
            process = proc
            postProcessLaunch()
        } catch {
            isBusy = false
            let msg = launchFailedMessage(error: error)
            onError?(msg)
            history.append(AgentMessage(role: .error, text: msg))
        }
    }

    func terminate() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        isRunning = false
        isBusy = false
    }

    // MARK: - Pipe & Process Setup

    func setupPipes(for proc: Process, terminationHandler: @escaping (Process) -> Void) {
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        proc.terminationHandler = terminationHandler

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.processOutput(text)
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

        outputPipe = outPipe
        errorPipe = errPipe
    }

    func createTerminationHandler() -> (Process) -> Void {
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

    // MARK: - Subclass Hooks

    func findBinaryName() -> String { fatalError("Subclasses must implement findBinaryName()") }
    func findBinaryFallbackPaths(home: String) -> [String] { fatalError("Subclasses must implement findBinaryFallbackPaths(home:)") }
    func findBinaryErrorKey() -> String { fatalError("Subclasses must implement findBinaryErrorKey()") }
    func installInstructions() -> String { fatalError("Subclasses must implement installInstructions()") }

    func configureProcess(_ proc: Process) {}
    func postProcessLaunch() {}

    func launchFailedMessage(error: Error) -> String {
        NSLocalizedString(findBinaryErrorKey(), comment: "") + ": \(error.localizedDescription)"
    }

    // MARK: - Common Utilities

    func processOutput(_ text: String) {
        lineBuffer += text
        while let newlineRange = lineBuffer.range(of: "\n") {
            let line = String(lineBuffer[lineBuffer.startIndex..<newlineRange.lowerBound])
            lineBuffer = String(lineBuffer[newlineRange.upperBound...])
            if !line.isEmpty {
                parseLine(line)
            }
        }
    }
}
