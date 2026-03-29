import Foundation

public enum CodexArchiveNaming {
    public static func archiveFilename(for email: String) -> String {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let encoded = Data(normalizedEmail.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "\(encoded).json"
    }
}
