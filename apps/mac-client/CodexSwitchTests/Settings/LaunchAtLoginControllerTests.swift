import XCTest
@testable import CodexSwitchKit

final class LaunchAtLoginControllerTests: XCTestCase {
    func testLiveLaunchAtLoginControllerTreatsRequiresApprovalAsEnabled() {
        let service = RecordingLaunchAtLoginSystemService(status: .requiresApproval)
        let controller = LiveLaunchAtLoginController(service: service)

        XCTAssertTrue(controller.isEnabled())
    }

    func testLiveLaunchAtLoginControllerRegistersAndUnregistersUnderlyingService() throws {
        let service = RecordingLaunchAtLoginSystemService(status: .notRegistered)
        let controller = LiveLaunchAtLoginController(service: service)

        try controller.setEnabled(true)
        try controller.setEnabled(false)

        XCTAssertEqual(service.operations, ["register", "unregister"])
    }
}

private final class RecordingLaunchAtLoginSystemService: LaunchAtLoginSystemServicing {
    var status: LaunchAtLoginSystemStatus
    private(set) var operations: [String] = []

    init(status: LaunchAtLoginSystemStatus) {
        self.status = status
    }

    func register() throws {
        operations.append("register")
        status = .enabled
    }

    func unregister() throws {
        operations.append("unregister")
        status = .notRegistered
    }
}
