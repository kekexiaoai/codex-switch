import XCTest
@testable import CodexSwitchKit

@MainActor
final class ProviderSyncViewTests: XCTestCase {
    func testProviderSyncViewUsesFlexibleFrameWhenEmbeddedInMainWindow() {
        let view = ProviderSyncView(
            viewModel: ProviderSyncViewModel(service: MockProviderSyncService()),
            layoutMode: .embeddedMainWindow
        )

        XCTAssertNil(view.fixedFrameSize)
    }
}
