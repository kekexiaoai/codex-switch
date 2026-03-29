import Foundation

public struct CodexUsageAPIClient {
    public enum Error: Swift.Error, Equatable {
        case accessTokenMissing
        case unauthorized
        case forbidden
        case notFound
        case rateLimited
        case server(statusCode: Int)
        case invalidResponse
        case network
    }

    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    private let transport: Transport
    private let now: () -> Date

    public init(
        transport: Transport? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.transport = transport ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw Error.invalidResponse
            }
            return (data, httpResponse)
        }
        self.now = now
    }

    public func fetchUsage(
        for account: Account,
        accessToken: String,
        accountID: String?
    ) async throws -> CodexUsageSnapshot {
        guard !accessToken.isEmpty else {
            throw Error.accessTokenMissing
        }

        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport(request)
        } catch let error as Error {
            throw error
        } catch {
            throw Error.network
        }

        switch response.statusCode {
        case 200..<300:
            break
        case 401:
            throw Error.unauthorized
        case 403:
            throw Error.forbidden
        case 404:
            throw Error.notFound
        case 429:
            throw Error.rateLimited
        case 500..<600:
            throw Error.server(statusCode: response.statusCode)
        default:
            throw Error.invalidResponse
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Error.invalidResponse
        }

        if let email = stringValue(in: object, paths: [["email"], ["account", "email"]]),
           let accountEmail = account.email,
           email.lowercased() != accountEmail.lowercased() {
            throw Error.invalidResponse
        }

        guard
            let rateLimitObject = dictionaryValue(in: object, paths: [["rate_limit"], ["rate_limits"]]),
            let primaryObject = dictionaryValue(
                in: rateLimitObject,
                paths: [["primary_window"], ["primary"], ["five_hour"]]
            ),
            let secondaryObject = dictionaryValue(
                in: rateLimitObject,
                paths: [["secondary_window"], ["secondary"], ["weekly"]]
            ),
            let fiveHour = decodeWindow(from: primaryObject),
            let weekly = decodeWindow(from: secondaryObject)
        else {
            throw Error.invalidResponse
        }

        let updatedAt = dateValue(value(in: object, path: ["updated_at"]))
            ?? dateValue(value(in: object, path: ["timestamp"]))
            ?? now()

        return CodexUsageSnapshot(
            accountID: account.id,
            updatedAt: updatedAt,
            fiveHour: CodexUsageWindow(percentUsed: fiveHour.usedPercent, resetsAt: fiveHour.resetsAt),
            weekly: CodexUsageWindow(percentUsed: weekly.usedPercent, resetsAt: weekly.resetsAt)
        )
    }

    private func decodeWindow(from object: [String: Any]) -> Window? {
        guard
            let usedPercent = intValue(object["used_percent"]),
            let resetsAt = dateValue(object["resets_at"] ?? object["reset_at"] ?? object["reset_time"])
        else {
            return nil
        }

        return Window(usedPercent: usedPercent, resetsAt: resetsAt)
    }

    private func stringValue(in object: [String: Any], paths: [[String]]) -> String? {
        for path in paths {
            if let value = value(in: object, path: path) as? String, !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private func dictionaryValue(in object: [String: Any], paths: [[String]]) -> [String: Any]? {
        for path in paths {
            if let value = value(in: object, path: path) as? [String: Any] {
                return value
            }
        }

        return nil
    }

    private func value(in object: [String: Any], path: [String]) -> Any? {
        var current: Any = object
        for component in path {
            guard let dictionary = current as? [String: Any], let next = dictionary[component] else {
                return nil
            }
            current = next
        }
        return current
    }

    private func intValue(_ value: Any?) -> Int? {
        switch value {
        case let intValue as Int:
            return intValue
        case let doubleValue as Double:
            return Int(doubleValue.rounded())
        case let number as NSNumber:
            return Int(number.doubleValue.rounded())
        default:
            return nil
        }
    }

    private func dateValue(_ value: Any?) -> Date? {
        switch value {
        case let string as String:
            return parseDate(string)
        case let intValue as Int:
            return Date(timeIntervalSince1970: TimeInterval(intValue))
        case let doubleValue as Double:
            return Date(timeIntervalSince1970: doubleValue)
        case let number as NSNumber:
            return Date(timeIntervalSince1970: number.doubleValue)
        default:
            return nil
        }
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

private extension CodexUsageAPIClient {
    struct Window {
        let usedPercent: Int
        let resetsAt: Date
    }
}
