import Foundation

/// Parses and modifies TOML config files for provider settings
public struct ConfigTomlParser {
    public init() {}

    // MARK: - Read Provider

    /// Reads the current model_provider from config.toml
    /// - Parameter configText: The TOML content
    /// - Returns: A tuple of (provider, isImplicit) where isImplicit is true if using default
    public func readCurrentProvider(from configText: String) -> (provider: String, implicit: Bool) {
        let lines = configText.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            if trimmed.hasPrefix("[") {
                break // Reached a section, root level ended
            }

            // Match: model_provider = "xxx"
            let pattern = #"^model_provider\s*=\s*"([^"]+)"\s*$"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let providerRange = Range(match.range(at: 1), in: trimmed) {
                let provider = String(trimmed[providerRange])
                return (provider, false)
            }
        }

        return ("openai", true) // Default
    }

    /// Reads provider from config file URL
    public func readCurrentProvider(from url: URL) throws -> (provider: String, implicit: Bool) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ("openai", true)
        }

        let text = try String(contentsOf: url, encoding: .utf8)
        return readCurrentProvider(from: text)
    }

    // MARK: - List Providers

    /// Lists all configured provider IDs from config.toml
    /// - Parameter configText: The TOML content
    /// - Returns: Sorted list of provider IDs
    public func listConfiguredProviderIds(from configText: String) -> [String] {
        var providerIds = Set<String>(["openai"]) // Always include default

        // Match: [model_providers.xxx]
        let pattern = #"^\[model_providers\.([A-Za-z0-9_.-]+)\]\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return ["openai"]
        }

        let range = NSRange(configText.startIndex..., in: configText)
        for match in regex.matches(in: configText, range: range) {
            if let providerRange = Range(match.range(at: 1), in: configText) {
                providerIds.insert(String(configText[providerRange]))
            }
        }

        return providerIds.sorted()
    }

    /// Checks if a provider is declared in the config
    public func configDeclaresProvider(_ configText: String, _ provider: String) -> Bool {
        listConfiguredProviderIds(from: configText).contains(provider)
    }

    // MARK: - Set Provider

    /// Sets the root model_provider in config text
    /// - Parameters:
    ///   - configText: Original TOML content
    ///   - provider: Provider ID to set
    /// - Returns: Modified TOML content
    public func setRootProvider(in configText: String, provider: String) -> String {
        var lines = configText.split(separator: "\n", omittingEmptySubsequences: false)
        var insertIndex = lines.count

        for i in 0..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                insertIndex = i + 1
                continue
            }
            if trimmed.hasPrefix("[") {
                insertIndex = i
                break
            }

            // Check for existing model_provider line
            let pattern = #"^model_provider\s*="#
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                lines[i] = Substring("model_provider = \"\(escapeTomlString(provider))\"")
                return reconstructText(from: lines, originalEndsWithNewline: configText.hasSuffix("\n"))
            }

            insertIndex = i + 1
        }

        // Insert new line
        lines.insert(Substring("model_provider = \"\(escapeTomlString(provider))\""), at: insertIndex)

        return reconstructText(from: lines, originalEndsWithNewline: configText.hasSuffix("\n"))
    }

    /// Writes provider to config file
    public func setRootProvider(in url: URL, provider: String) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let updated = setRootProvider(in: text, provider: provider)
        try updated.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Private Helpers

    private func escapeTomlString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func reconstructText(from lines: [Substring], originalEndsWithNewline: Bool) -> String {
        let joined = lines.joined(separator: "\n")
        if originalEndsWithNewline {
            return joined.hasSuffix("\n") ? joined : joined + "\n"
        }
        return joined
    }
}
