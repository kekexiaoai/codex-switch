import SwiftUI

public struct StatusWindowView: View {
    let snapshot: StatusSnapshot

    public init() {
        self.snapshot = .preview
    }

    public init(snapshot: StatusSnapshot) {
        self.snapshot = snapshot
    }

    var sectionTitles: [String] {
        ["Operations", "Usage", "Accounts", "Diagnostics", "Paths"]
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Status Page")
                    .font(.title2.weight(.semibold))
                Text(snapshot.updatedText.isEmpty ? snapshot.usageStatusText : snapshot.updatedText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                StatusView(snapshot: snapshot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .frame(minWidth: 520, minHeight: 560)
    }
}
