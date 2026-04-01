import Foundation

public struct CodexConfigParser {
    private let fileURL: URL
    private let fileManager: FileManager

    public static let defaultProvider = "openai"

    public init(paths: CodexPaths, fileManager: FileManager = .default) {
        self.fileURL = paths.configFileURL
        self.fileManager = fileManager
    }

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public func currentProvider() throws -> String {
        guard let text = try? readConfigText() else {
            return Self.defaultProvider
        }

        return Self.parseCurrentProvider(from: text)
    }

    public func configuredProviders() throws -> [String] {
        guard let text = try? readConfigText() else {
            return [Self.defaultProvider]
        }

        return Self.parseConfiguredProviders(from: text)
    }

    public func setProvider(_ provider: String) throws {
        let originalText: String
        if fileManager.fileExists(atPath: fileURL.path) {
            originalText = try readConfigText()
        } else {
            originalText = ""
        }

        let updatedText = Self.setRootProviderInConfigText(originalText, provider: provider)
        try Data(updatedText.utf8).write(to: fileURL, options: .atomic)
    }

    public func readConfigText() throws -> String {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw ProviderSyncError.configFileNotFound
        }

        let data = try Data(contentsOf: fileURL)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ProviderSyncError.configParseError("File is not valid UTF-8")
        }

        return text
    }

    // MARK: - Static Parsing

    static func parseCurrentProvider(from text: String) -> String {
        let providerPattern = #"^\s*model_provider\s*=\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: providerPattern, options: .anchorsMatchLines) else {
            return defaultProvider
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let captureRange = Range(match.range(at: 1), in: text) else {
            return defaultProvider
        }

        return String(text[captureRange])
    }

    static func parseConfiguredProviders(from text: String) -> [String] {
        var providers = Set<String>([defaultProvider])

        let sectionPattern = #"^\[model_providers\.([A-Za-z0-9_.-]+)]\s*$"#
        guard let regex = try? NSRegularExpression(pattern: sectionPattern, options: .anchorsMatchLines) else {
            return Array(providers).sorted()
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        for match in matches {
            if let captureRange = Range(match.range(at: 1), in: text) {
                providers.insert(String(text[captureRange]))
            }
        }

        return Array(providers).sorted()
    }

    static func setRootProviderInConfigText(_ text: String, provider: String) -> String {
        let providerLine = "model_provider = \"\(provider)\""
        let providerPattern = #"^\s*model_provider\s*=\s*"[^"]*""#

        guard let regex = try? NSRegularExpression(pattern: providerPattern, options: .anchorsMatchLines) else {
            return text.isEmpty ? providerLine + "\n" : providerLine + "\n" + text
        }

        let range = NSRange(text.startIndex..., in: text)
        if regex.firstMatch(in: text, range: range) != nil {
            return regex.stringByReplacingMatches(in: text, range: range, withTemplate: providerLine)
        }

        // Insert before the first [section] header
        let sectionPattern = #"^\["#
        if let sectionRegex = try? NSRegularExpression(pattern: sectionPattern, options: .anchorsMatchLines),
           let sectionMatch = sectionRegex.firstMatch(in: text, range: range),
           let sectionStart = Range(sectionMatch.range, in: text) {
            var result = text
            result.insert(contentsOf: providerLine + "\n\n", at: sectionStart.lowerBound)
            return result
        }

        // Append to end
        if text.isEmpty {
            return providerLine + "\n"
        }

        let separator = text.hasSuffix("\n") ? "" : "\n"
        return text + separator + providerLine + "\n"
    }
}
