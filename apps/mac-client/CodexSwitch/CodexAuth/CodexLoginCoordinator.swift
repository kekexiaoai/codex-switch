import Foundation

public enum CodexLoginResult: Equatable {
    case success
    case started
    case cancelled
    case failure
}

public protocol CodexLoginRunning {
    func runLogin() async throws -> CodexLoginResult
}

public struct StubCodexLoginRunner: CodexLoginRunning {
    private let result: CodexLoginResult

    public init(result: CodexLoginResult) {
        self.result = result
    }

    public func runLogin() async throws -> CodexLoginResult {
        result
    }
}

public struct ProcessCodexLoginRunner: CodexLoginRunning {
    public init() {}

    public static func makeProcess() -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            """
            tell application "Terminal"
                activate
                do script "clear; echo 'Codex Switch opened this Terminal window for browser login.'; echo 'If browser login does not start automatically, run /login in Codex below.'; codex login; status=$?; if [ $status -ne 0 ]; then echo ''; echo 'Falling back to interactive Codex. Run /login if needed.'; exec codex; fi"
            end tell
            """
        ]
        return process
    }

    public static func result(forExitStatus status: Int32) -> CodexLoginResult {
        switch status {
        case 0:
            return .success
        case 130, 143:
            return .cancelled
        default:
            return .failure
        }
    }

    public func runLogin() async throws -> CodexLoginResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Self.makeProcess()
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume(returning: .started)
                } else {
                    continuation.resume(returning: Self.result(forExitStatus: process.terminationStatus))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: CodexAuthError.loginFailed)
            }
        }
    }
}

public struct CodexLoginCoordinator {
    private let runner: any CodexLoginRunning
    private let importer: CodexAuthImporter
    private let fileStore: CodexAuthFileStore
    private let pollIntervalNanoseconds: UInt64
    private let maxPollAttempts: Int
    private let wait: @Sendable (UInt64) async throws -> Void

    public init(
        runner: any CodexLoginRunning,
        importer: CodexAuthImporter,
        fileStore: CodexAuthFileStore,
        pollIntervalNanoseconds: UInt64 = 500_000_000,
        maxPollAttempts: Int = 240,
        wait: @escaping @Sendable (UInt64) async throws -> Void = { duration in
            try await Task.sleep(nanoseconds: duration)
        }
    ) {
        self.runner = runner
        self.importer = importer
        self.fileStore = fileStore
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
        self.maxPollAttempts = maxPollAttempts
        self.wait = wait
    }

    public func loginAndImport() async throws -> Account {
        let previousAuthData = try? fileStore.readCurrentAuthData()
        let result = try await runner.runLogin()
        switch result {
        case .success:
            return try importer.importCurrentAccount(source: .browserLogin)
        case .started:
            if let updatedAccount = try await waitForUpdatedAuth(since: previousAuthData) {
                return updatedAccount
            }
            throw CodexAuthError.loginFailed
        case .cancelled:
            throw CodexAuthError.loginCancelled
        case .failure:
            if let updatedAccount = try importAccountIfAuthChanged(since: previousAuthData) {
                return updatedAccount
            }
            throw CodexAuthError.loginFailed
        }
    }

    private func waitForUpdatedAuth(since previousAuthData: Data?) async throws -> Account? {
        for _ in 0..<maxPollAttempts {
            if let updatedAccount = try importAccountIfAuthChanged(since: previousAuthData) {
                return updatedAccount
            }
            try await wait(pollIntervalNanoseconds)
        }

        return try importAccountIfAuthChanged(since: previousAuthData)
    }

    private func importAccountIfAuthChanged(since previousAuthData: Data?) throws -> Account? {
        guard let currentAuthData = try? fileStore.readCurrentAuthData() else {
            return nil
        }

        guard currentAuthData != previousAuthData else {
            return nil
        }

        return try importer.importAuthData(currentAuthData, source: .browserLogin)
    }
}
