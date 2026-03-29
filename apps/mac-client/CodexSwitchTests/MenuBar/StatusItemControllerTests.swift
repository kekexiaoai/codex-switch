import AppKit
import XCTest
@testable import CodexSwitchKit

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testStatusItemUsesTemplateImageAndLargerPopoverSize() {
        let image = StatusItemController.statusItemImage()

        XCTAssertNotNil(image)
        XCTAssertEqual(image?.isTemplate, true)
        XCTAssertEqual(StatusItemController.statusItemAccessibilityTitle, "Codex Switch")
        XCTAssertEqual(image?.size, NSSize(width: 18, height: 18))
    }

    func testPopoverSizeClampsToMinimumAndMaximumHeight() {
        XCTAssertEqual(
            StatusItemController.preferredPopoverContentSize(forContentHeight: 200),
            NSSize(width: 360, height: 420)
        )
        XCTAssertEqual(
            StatusItemController.preferredPopoverContentSize(forContentHeight: 560),
            NSSize(width: 360, height: 560)
        )
        XCTAssertEqual(
            StatusItemController.preferredPopoverContentSize(forContentHeight: 1200),
            NSSize(width: 360, height: 720)
        )
    }

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

    func testStatusWindowPresenterReusesWindowControllerAndRefreshesSnapshotOnEachOpen() async {
        let firstSnapshot = StatusSnapshot.preview
        let secondSnapshot = StatusSnapshot(
            activeAccount: firstSnapshot.activeAccount,
            activeAccountStatusText: firstSnapshot.activeAccountStatusText,
            archivedAccountCount: firstSnapshot.archivedAccountCount,
            accountInventoryStatusText: firstSnapshot.accountInventoryStatusText,
            updatedText: "Updated after refresh",
            usageStatusText: "Updated after refresh",
            summaries: firstSnapshot.summaries,
            accountRows: firstSnapshot.accountRows,
            runtimeModeLabel: firstSnapshot.runtimeModeLabel,
            currentHostLabel: firstSnapshot.currentHostLabel,
            preferredHostLabel: firstSnapshot.preferredHostLabel,
            paths: firstSnapshot.paths,
            diagnostics: firstSnapshot.diagnostics
        )

        var loadCount = 0
        var makeCount = 0
        var presentedControllers: [NSWindowController] = []
        var renderedStatuses: [String] = []
        let snapshotSequence = SnapshotSequence(snapshots: [firstSnapshot, secondSnapshot])
        let presenter = StatusWindowPresenter(
            loadSnapshot: {
                await snapshotSequence.next()
            },
            makeWindowController: { snapshot in
                makeCount += 1
                renderedStatuses.append(snapshot.updatedText)
                return NSWindowController(window: NSWindow())
            },
            updateWindowController: { _, snapshot in
                renderedStatuses.append(snapshot.updatedText)
            },
            presentWindowController: { controller in
                presentedControllers.append(controller)
            }
        )

        await presenter.present()
        await presenter.present()

        loadCount = await snapshotSequence.loadCount
        XCTAssertEqual(loadCount, 2)
        XCTAssertEqual(makeCount, 1)
        XCTAssertEqual(renderedStatuses, ["Updated 10 seconds ago", "Updated after refresh"])
        XCTAssertEqual(presentedControllers.count, 2)
        XCTAssertTrue(presentedControllers[0] === presentedControllers[1])
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

private actor SnapshotSequence {
    private let snapshots: [StatusSnapshot]
    private var nextIndex = 0
    private(set) var loadCount = 0

    init(snapshots: [StatusSnapshot]) {
        self.snapshots = snapshots
    }

    func next() -> StatusSnapshot {
        let index = min(nextIndex, snapshots.count - 1)
        nextIndex += 1
        loadCount += 1
        return snapshots[index]
    }
}
