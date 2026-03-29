import AppKit
import XCTest
@testable import CodexSwitchKit

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testPopoverPresenterActivatesAppBeforeShowingPopover() {
        var events: [String] = []

        let presenter = MenuBarPopoverPresenter(
            activateApp: { events.append("activate") },
            showPopover: { events.append("show") },
            makePopoverInteractive: { events.append("interactive") },
            startOutsideClickMonitor: { events.append("monitor") }
        )

        presenter.present()

        XCTAssertEqual(events, ["activate", "show", "interactive", "monitor"])
    }

    func testOutsideClickMonitorOnlyDismissesForClicksOutsideWatchedWindows() async {
        var localHandler: ((NSEvent) -> NSEvent?)?
        var globalHandler: ((NSEvent) -> Void)?
        let insideWindow = NSWindow()
        let outsideWindow = NSWindow()
        var resolvedWindow: NSWindow? = insideWindow
        var dismissCount = 0
        let globalDismissExpectation = expectation(description: "global outside click dismissed")

        let monitor = PopoverOutsideClickMonitor(
            watchedWindows: { [insideWindow] },
            addLocalMonitor: { _, handler in
                localHandler = handler
                return "local-monitor"
            },
            addGlobalMonitor: { _, handler in
                globalHandler = handler
                return "global-monitor"
            },
            removeMonitor: { _ in },
            eventWindow: { _ in resolvedWindow },
            onOutsideClick: {
                dismissCount += 1
                if dismissCount == 2 {
                    globalDismissExpectation.fulfill()
                }
            }
        )

        monitor.start()
        let event = mouseDownEvent()

        _ = localHandler?(event)
        XCTAssertEqual(dismissCount, 0)

        resolvedWindow = outsideWindow
        _ = localHandler?(event)
        XCTAssertEqual(dismissCount, 1)

        globalHandler?(event)
        wait(for: [globalDismissExpectation], timeout: 1)
        XCTAssertEqual(dismissCount, 2)
    }

    func testOutsideClickMonitorRemovesInstalledMonitorsWhenStopped() {
        var removedMonitors: [String] = []

        let monitor = PopoverOutsideClickMonitor(
            watchedWindows: { [] },
            addLocalMonitor: { _, _ in "local-monitor" },
            addGlobalMonitor: { _, _ in "global-monitor" },
            removeMonitor: { token in
                removedMonitors.append(token as! String)
            },
            eventWindow: { _ in nil },
            onOutsideClick: {}
        )

        monitor.start()
        monitor.stop()

        XCTAssertEqual(removedMonitors.sorted(), ["global-monitor", "local-monitor"])
    }

    private func mouseDownEvent() -> NSEvent {
        NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }
}
