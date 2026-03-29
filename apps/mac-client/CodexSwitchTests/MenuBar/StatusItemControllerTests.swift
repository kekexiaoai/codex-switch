import AppKit
import SwiftUI
import XCTest
@testable import CodexSwitchKit

@MainActor
final class StatusItemControllerTests: XCTestCase {
    func testStatusItemUsesTemplateImageAndLargerPopoverSize() {
        let image = StatusItemController.statusItemImage(style: .highContrastLight)
        let boldImage = StatusItemController.statusItemImage(style: .highContrastLightBold)

        XCTAssertNotNil(image)
        XCTAssertEqual(image?.isTemplate, false)
        XCTAssertEqual(StatusItemController.statusItemAccessibilityTitle, "Codex Switch")
        XCTAssertEqual(image?.size, NSSize(width: 18, height: 18))
        XCTAssertNotNil(boldImage)
        XCTAssertEqual(boldImage?.isTemplate, false)
        XCTAssertEqual(boldImage?.size, NSSize(width: 18, height: 18))
    }

    func testStatusItemMapsStylesToExpectedResourceNames() {
        XCTAssertEqual(StatusItemController.resourceName(for: .highContrastLight), "StatusBarIconLightHighContrast")
        XCTAssertEqual(StatusItemController.resourceName(for: .highContrastLightBold), "StatusBarIconLightHighContrastBold")
    }

    func testPopoverSizeClampsToMinimumAndMaximumHeight() {
        XCTAssertEqual(
            StatusItemController.preferredPopoverContentSize(forContentHeight: 200),
            NSSize(width: 360, height: 380)
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

    func testPanelOnlyReportsMeaningfulHeightChanges() {
        XCTAssertTrue(
            MenuBarPanelView.shouldReportPreferredHeight(
                MenuBarPanelView.normalizedPreferredHeight(605.5),
                previous: nil
            )
        )
        XCTAssertFalse(
            MenuBarPanelView.shouldReportPreferredHeight(
                MenuBarPanelView.normalizedPreferredHeight(605.49),
                previous: MenuBarPanelView.normalizedPreferredHeight(605.5)
            )
        )
        XCTAssertFalse(
            MenuBarPanelView.shouldReportPreferredHeight(
                MenuBarPanelView.normalizedPreferredHeight(605.74),
                previous: MenuBarPanelView.normalizedPreferredHeight(605.5)
            )
        )
        XCTAssertTrue(
            MenuBarPanelView.shouldReportPreferredHeight(
                MenuBarPanelView.normalizedPreferredHeight(702.0),
                previous: MenuBarPanelView.normalizedPreferredHeight(605.5)
            )
        )
    }

    func testHostingControllerCanBeCreatedForMenuBarShellView() {
        let hostingController = MenuBarHostingController(
            rootView: MenuBarShellView(viewModel: .preview)
        )

        XCTAssertNotNil(hostingController.view)
    }

    func testPanelReportsDifferentContentHeightsWhenAccountCountChanges() async {
        let service = SnapshotSequenceMenuBarService(
            snapshots: [
                makeSnapshot(accountCount: 8),
                makeSnapshot(accountCount: 2),
            ]
        )
        let viewModel = MenuBarViewModel(service: service)
        var reportedHeights: [CGFloat] = []
        let hostingController = NSHostingController(
            rootView: MenuBarPanelView(
                viewModel: viewModel,
                onPreferredHeightChange: { reportedHeights.append($0) }
            )
        )
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: StatusItemController.popoverWidth,
                height: StatusItemController.maxPopoverHeight
            ),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hostingController

        _ = hostingController.view
        hostingController.view.frame = NSRect(
            x: 0,
            y: 0,
            width: StatusItemController.popoverWidth,
            height: StatusItemController.maxPopoverHeight
        )

        let firstBaseline = reportedHeights.count
        await viewModel.refresh()
        try? await waitForCondition { reportedHeights.count > firstBaseline }
        try? await Task.sleep(nanoseconds: 200_000_000)
        let firstPhaseHeights = Array(reportedHeights.dropFirst(firstBaseline))
        let expandedHeight = firstPhaseHeights.max() ?? 0

        let secondBaseline = reportedHeights.count
        await viewModel.refresh()
        try? await waitForCondition { reportedHeights.count > secondBaseline }
        try? await Task.sleep(nanoseconds: 200_000_000)
        let secondPhaseHeights = Array(reportedHeights.dropFirst(secondBaseline))
        let shrunkenHeight = secondPhaseHeights.min() ?? 0

        XCTAssertGreaterThan(expandedHeight, 0)
        XCTAssertLessThan(shrunkenHeight, expandedHeight)
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

    private func makeSnapshot(accountCount: Int) -> MenuBarSnapshot {
        MenuBarSnapshot(
            headerEmail: "a@example.com",
            headerTier: "Plus",
            updatedText: "Updated just now",
            usageSourceText: "Auto",
            summaries: [
                UsageSummaryModel(id: "5h", title: "5 Hours", percentUsed: 42, resetText: "Resets soon"),
                UsageSummaryModel(id: "weekly", title: "Weekly", percentUsed: 17, resetText: "Resets later"),
            ],
            accounts: (0..<accountCount).map { index in
                AccountRowModel(
                    id: "acct-\(index)",
                    emailMask: "user\(index)@example.com",
                    tierLabel: index == 0 ? "Pro" : "Plus",
                    fiveHourPercent: (index * 7) % 100,
                    weeklyPercent: (index * 11) % 100,
                    isActive: index == 0
                )
            }
        )
    }
}

private func waitForCondition(
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    pollIntervalNanoseconds: UInt64 = 20_000_000,
    condition: @escaping () -> Bool
) async throws {
    let start = DispatchTime.now().uptimeNanoseconds
    while !condition() {
        if DispatchTime.now().uptimeNanoseconds - start > timeoutNanoseconds {
            throw CancellationError()
        }
        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
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

private actor SnapshotSequenceMenuBarService: MenuBarSnapshotService {
    private let snapshots: [MenuBarSnapshot]
    private var index = 0

    init(snapshots: [MenuBarSnapshot]) {
        self.snapshots = snapshots
    }

    func loadSnapshot(triggerUsageRefresh: Bool) async -> MenuBarSnapshot {
        let currentIndex = min(index, snapshots.count - 1)
        index += 1
        return snapshots[currentIndex]
    }
}
