import Foundation

public actor ApplicationSupportAccountStore: AccountMetadataStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public init(
        fileManager: FileManager = .default,
        bundleIdentifier: String = "com.codex.switch"
    ) throws {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent(bundleIdentifier, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("accounts.json")
    }

    public func loadAccounts() throws -> [Account] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([Account].self, from: data)
    }

    public func saveAccounts(_ accounts: [Account]) throws {
        let data = try encoder.encode(accounts)
        try data.write(to: fileURL, options: .atomic)
    }
}
