import Foundation

public protocol SwitchCommandRunning {
    func activateAccount(id: String) async throws
}

public struct StubSwitchCommandRunner: SwitchCommandRunning {
    public init() {}

    public func activateAccount(id: String) async throws {}
}
