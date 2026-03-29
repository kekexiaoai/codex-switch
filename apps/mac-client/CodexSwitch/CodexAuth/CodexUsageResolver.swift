import Foundation

public struct CodexUsageResolver {
    private let scanner: CodexUsageScanner
    private let apiClient: CodexUsageAPIClient
    private let logger: any CodexDiagnosticsLogging

    public init(
        scanner: CodexUsageScanner,
        apiClient: CodexUsageAPIClient = CodexUsageAPIClient(),
        logger: any CodexDiagnosticsLogging = NullCodexDiagnosticsLogger()
    ) {
        self.scanner = scanner
        self.apiClient = apiClient
        self.logger = logger
    }

    public func refreshUsage(
        for account: Account,
        authData: Data,
        mode: CodexUsageSourceMode
    ) async throws -> CodexUsageSnapshot {
        logger.log("usage_refresh_started mode=\(mode.rawValue) account=\(account.id)")
        switch mode {
        case .automatic:
            if let authContext = try? parseAuthContext(from: authData),
               let accessToken = authContext.accessToken,
               !accessToken.isEmpty {
                logger.log("usage_refresh_api_started account=\(account.id)")
                do {
                    let snapshot = try await apiClient.fetchUsage(
                        for: account,
                        accessToken: accessToken,
                        accountID: authContext.transportAccountID
                    )
                    try scanner.saveCachedSnapshot(snapshot)
                    logger.log("usage_refresh_api_succeeded account=\(account.id)")
                    return snapshot
                } catch let error as CodexUsageAPIClient.Error {
                    logger.log("usage_refresh_api_failed account=\(account.id) reason=\(error.logValue)")
                } catch {
                    logger.log("usage_refresh_api_failed account=\(account.id) reason=unknown")
                }
            } else {
                logger.log("usage_refresh_api_skipped account=\(account.id) reason=missing_access_token")
            }

            return logLocalRefresh(
                try scanner.refreshUsageResult(for: account),
                mode: mode,
                account: account
            )
        case .localOnly:
            return logLocalRefresh(
                try scanner.refreshUsageResult(for: account),
                mode: mode,
                account: account
            )
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

    private func logLocalRefresh(
        _ result: CodexUsageScanResult,
        mode: CodexUsageSourceMode,
        account: Account
    ) -> CodexUsageSnapshot {
        logger.log(
            "usage_refresh_local_succeeded mode=\(mode.rawValue) account=\(account.id) source=\(result.source.rawValue)"
        )
        return result.snapshot
    }
}

private extension CodexUsageResolver {
    struct AuthContext {
        let accessToken: String?
        let transportAccountID: String?
    }
}

private extension CodexUsageAPIClient.Error {
    var logValue: String {
        switch self {
        case .accessTokenMissing:
            return "access_token_missing"
        case .unauthorized:
            return "unauthorized"
        case .forbidden:
            return "forbidden"
        case .notFound:
            return "not_found"
        case .rateLimited:
            return "rate_limited"
        case let .server(statusCode):
            return "server_\(statusCode)"
        case .invalidResponse:
            return "invalid_response"
        case .network:
            return "network"
        }
    }
}
