import SwiftUI

public struct StatusWindowView: View {
    let snapshot: StatusSnapshot
    let preferredLanguages: [String]?

    public init() {
        self.snapshot = .preview
        self.preferredLanguages = nil
    }

    public init(snapshot: StatusSnapshot, preferredLanguages: [String]? = nil) {
        self.snapshot = snapshot
        self.preferredLanguages = preferredLanguages
    }

    var sectionTitles: [String] {
        [
            StatusStrings.text(.operations, preferredLanguages: preferredLanguages),
            StatusStrings.text(.usage, preferredLanguages: preferredLanguages),
            StatusStrings.text(.accounts, preferredLanguages: preferredLanguages),
            StatusStrings.text(.diagnostics, preferredLanguages: preferredLanguages),
            StatusStrings.text(.paths, preferredLanguages: preferredLanguages),
        ]
    }

    var pageTitle: String {
        StatusStrings.text(.statusPageTitle, preferredLanguages: preferredLanguages)
    }

    var activeAccountTitle: String {
        snapshot.activeAccountStatusText
    }

    var activeAccountDetails: [String] {
        guard let activeAccount = snapshot.activeAccount else {
            return []
        }

        return [
            activeAccount.tierLabel,
            activeAccount.sourceLabel,
            activeAccount.archiveFilename,
            snapshot.usageStatusText,
            snapshot.updatedText,
        ]
    }

    var usageTitles: [String] {
        snapshot.summaries.map(\.title)
    }

    var accountEmails: [String] {
        snapshot.accountRows.map(\.emailMask)
    }

    var diagnosticsLines: [String] {
        snapshot.diagnostics.recentEvents
    }

    var pathLines: [String] {
        [
            snapshot.paths.authFilePath,
            snapshot.paths.accountsDirectoryPath,
            snapshot.paths.diagnosticsDirectoryPath,
            snapshot.paths.browserLoginLogPath,
            snapshot.paths.usageRefreshLogPath,
        ]
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text(pageTitle)
                    .font(.title2.weight(.semibold))
                Text(snapshot.updatedText.isEmpty ? snapshot.usageStatusText : snapshot.updatedText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                StatusView(snapshot: snapshot, preferredLanguages: preferredLanguages)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .frame(minWidth: 520, minHeight: 560)
    }
}
