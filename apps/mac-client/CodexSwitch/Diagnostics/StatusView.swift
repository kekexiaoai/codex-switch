import SwiftUI

public struct StatusView: View {
    private let snapshot: StatusSnapshot

    public init() {
        self.snapshot = .preview
    }

    public init(snapshot: StatusSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            operationsSection
            usageSection
            accountsSection
            diagnosticsSection
            pathsSection
        }
        .font(.subheadline)
    }

    private var operationsSection: some View {
        statusCard(title: "Operations", systemImage: "person.crop.circle") {
            infoRow(label: "Active account", value: snapshot.activeAccountStatusText)
            if let activeAccount = snapshot.activeAccount {
                infoRow(label: "Tier", value: activeAccount.tierLabel)
                infoRow(label: "Source", value: activeAccount.sourceLabel)
                infoRow(label: "Archive", value: activeAccount.archiveFilename)
            }
            infoRow(label: "Accounts", value: snapshot.accountInventoryStatusText)
            infoRow(label: "Usage Source", value: snapshot.usageStatusText)
            infoRow(label: "Usage Updated", value: snapshot.updatedText)
        }
    }

    private var usageSection: some View {
        statusCard(title: "Usage", systemImage: "gauge.with.dots.needle.67percent") {
            if snapshot.summaries.isEmpty {
                Text("No usage data")
                    .foregroundColor(.secondary)
            } else {
                ForEach(snapshot.summaries) { summary in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(summary.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(summary.percentUsed)%")
                                .foregroundColor(.secondary)
                        }
                        ProgressView(value: Double(summary.percentUsed), total: 100)
                        Text(summary.resetText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var accountsSection: some View {
        statusCard(title: "Accounts", systemImage: "person.2") {
            if snapshot.accountRows.isEmpty {
                Text("No archived accounts")
                    .foregroundColor(.secondary)
            } else {
                ForEach(snapshot.accountRows) { account in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(account.emailMask)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(account.tierLabel)
                                .foregroundColor(.secondary)
                        }
                        Text("5h \(account.fiveHourPercent)%  •  Weekly \(account.weeklyPercent)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var diagnosticsSection: some View {
        statusCard(title: "Diagnostics", systemImage: "waveform.path.ecg") {
            infoRow(label: "Runtime mode", value: snapshot.runtimeModeLabel)
            infoRow(label: "Current host", value: snapshot.currentHostLabel)
            infoRow(label: "Preferred host", value: snapshot.preferredHostLabel)
            infoRow(label: "Status", value: snapshot.diagnostics.statusText)

            if !snapshot.diagnostics.recentEvents.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent events")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    ForEach(snapshot.diagnostics.recentEvents, id: \.self) { event in
                        Text(event)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var pathsSection: some View {
        statusCard(title: "Paths", systemImage: "folder") {
            pathRow(label: "Auth", value: snapshot.paths.authFilePath)
            pathRow(label: "Accounts", value: snapshot.paths.accountsDirectoryPath)
            pathRow(label: "Diagnostics Directory", value: snapshot.paths.diagnosticsDirectoryPath)
            pathRow(label: "Browser Login Log", value: snapshot.paths.browserLoginLogPath)
            pathRow(label: "Usage Refresh Log", value: snapshot.paths.usageRefreshLogPath)
        }
    }

    private func statusCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    private func pathRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}
