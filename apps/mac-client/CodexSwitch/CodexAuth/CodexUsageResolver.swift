import Foundation

public struct CodexUsageResolver {
    private let scanner: CodexUsageScanner
    private let apiClient: CodexUsageAPIClient

    public init(scanner: CodexUsageScanner, apiClient: CodexUsageAPIClient = CodexUsageAPIClient()) {
        self.scanner = scanner
        self.apiClient = apiClient
    }

    public func refreshUsage(
        for account: Account,
        authData: Data,
        mode: CodexUsageSourceMode
    ) async throws -> CodexUsageSnapshot {
        switch mode {
        case .automatic:
            if let authContext = try? parseAuthContext(from: authData),
               let accessToken = authContext.accessToken,
               !accessToken.isEmpty,
               let snapshot = try? await apiClient.fetchUsage(
                    for: account,
                    accessToken: accessToken,
                    accountID: authContext.transportAccountID
               ) {
                try scanner.saveCachedSnapshot(snapshot)
                return snapshot
            }

            return try scanner.refreshUsage(for: account)
        case .localOnly:
            return try scanner.refreshUsage(for: account)
        }
    }

    private func parseAuthContext(from data: Data) throws -> AuthContext {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = object["tokens"] as? [String: Any] else {
            throw CodexAuthError.authJSONInvalid
        }

        let accessToken = tokens["access_token"] as? String
        let transportAccountID = tokens["account_id"] as? String

        if let idToken = tokens["id_token"] as? String,
           let claims = try? CodexJWTDecoder().decode(idToken: idToken) {
            return AuthContext(
                accessToken: accessToken,
                transportAccountID: transportAccountID ?? claims.accountID
            )
        }

        return AuthContext(accessToken: accessToken, transportAccountID: transportAccountID)
    }
}

private extension CodexUsageResolver {
    struct AuthContext {
        let accessToken: String?
        let transportAccountID: String?
    }
}
