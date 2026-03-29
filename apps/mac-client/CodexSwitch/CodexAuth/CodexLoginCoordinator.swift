import Foundation

public enum CodexLoginResult: Equatable {
    case success
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
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", "codex login"]
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
                continuation.resume(returning: Self.result(forExitStatus: process.terminationStatus))
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

    public init(runner: any CodexLoginRunning, importer: CodexAuthImporter, fileStore: CodexAuthFileStore) {
        self.runner = runner
        self.importer = importer
        self.fileStore = fileStore
    }

    public func loginAndImport() async throws -> Account {
        let previousAuthData = try? fileStore.readCurrentAuthData()
        let result = try await runner.runLogin()
        switch result {
        case .success:
            return try importer.importCurrentAccount(source: .browserLogin)
        case .cancelled:
            throw CodexAuthError.loginCancelled
        case .failure:
            if let updatedAccount = try importAccountIfAuthChanged(since: previousAuthData) {
                return updatedAccount
            }
            throw CodexAuthError.loginFailed
        }
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
