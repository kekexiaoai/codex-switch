import Foundation

public enum MenuBarAction: Equatable {
    case openStatusPage
    case openSettings
    case openProviderSync
    case quit
}

@MainActor
public protocol MenuBarActionHandling {
    func handle(_ action: MenuBarAction)
}

@MainActor
public final class RecordingMenuBarActionHandler: MenuBarActionHandling {
    public private(set) var recordedActions: [MenuBarAction] = []

    public init() {}

    public func handle(_ action: MenuBarAction) {
        recordedActions.append(action)
    }
}
