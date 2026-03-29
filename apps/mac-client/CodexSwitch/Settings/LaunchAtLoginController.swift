import Foundation
#if canImport(ServiceManagement)
import ServiceManagement
#endif

public protocol LaunchAtLoginControlling {
    func isEnabled() -> Bool
    func setEnabled(_ enabled: Bool) throws
}

public enum LaunchAtLoginControllerError: LocalizedError, Equatable {
    case unsupportedOS
    case systemRegistrationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            return "Launch at Login requires macOS 13 or newer."
        case .systemRegistrationFailed(let message):
            return message
        }
    }
}

enum LaunchAtLoginSystemStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

protocol LaunchAtLoginSystemServicing {
    var status: LaunchAtLoginSystemStatus { get }
    func register() throws
    func unregister() throws
}

public struct LiveLaunchAtLoginController: LaunchAtLoginControlling {
    private let service: any LaunchAtLoginSystemServicing

    public init() {
        self.init(service: DefaultLaunchAtLoginSystemService())
    }

    init(service: any LaunchAtLoginSystemServicing) {
        self.service = service
    }

    public func isEnabled() -> Bool {
        switch service.status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        }
    }

    public func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }
}

private struct DefaultLaunchAtLoginSystemService: LaunchAtLoginSystemServicing {
    var status: LaunchAtLoginSystemStatus {
        guard #available(macOS 13.0, *) else {
            return .notFound
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        case .notRegistered:
            return .notRegistered
        @unknown default:
            return .notFound
        }
    }

    func register() throws {
        guard #available(macOS 13.0, *) else {
            throw LaunchAtLoginControllerError.unsupportedOS
        }

        do {
            try SMAppService.mainApp.register()
        } catch {
            throw LaunchAtLoginControllerError.systemRegistrationFailed(error.localizedDescription)
        }
    }

    func unregister() throws {
        guard #available(macOS 13.0, *) else {
            throw LaunchAtLoginControllerError.unsupportedOS
        }

        do {
            try SMAppService.mainApp.unregister()
        } catch {
            throw LaunchAtLoginControllerError.systemRegistrationFailed(error.localizedDescription)
        }
    }
}
