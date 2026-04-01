import SwiftUI

@MainActor
public struct ProviderSyncView: View {
    @StateObject private var viewModel: ProviderSyncViewModel

    public init(viewModel: ProviderSyncViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Provider Sync")
                    .font(.title2.weight(.semibold))

                statusSection
                distributionSection
                syncSection
                backupsSection
            }
            .padding(20)
        }
        .frame(width: 520, height: 640)
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial)
            }
        }
        .alert(
            viewModel.lastMessage?.title ?? "Provider Sync",
            isPresented: Binding(
                get: { viewModel.lastMessage != nil },
                set: { if !$0 { viewModel.dismissMessage() } }
            ),
            presenting: viewModel.lastMessage
        ) { _ in
            Button("OK", role: .cancel) {
                viewModel.dismissMessage()
            }
        } message: { message in
            Text(message.message)
        }
        .task {
            await viewModel.loadStatus()
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        section("Current Status") {
            HStack {
                Text("Active Provider")
                    .font(.subheadline)
                Spacer()
                Text(viewModel.currentProvider)
                    .font(.body.weight(.semibold))
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Configured Providers")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    ForEach(viewModel.configuredProviders, id: \.self) { provider in
                        Text(provider)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(provider == viewModel.currentProvider
                                          ? Color.accentColor.opacity(0.15)
                                          : Color.primary.opacity(0.06))
                            )
                    }
                }
            }
        }
    }

    // MARK: - Distribution

    private var distributionSection: some View {
        section("Session Distribution") {
            if !viewModel.rolloutDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rollout Files")
                        .font(.subheadline.weight(.medium))
                    distributionTable(viewModel.rolloutDistribution)
                }
            }

            if !viewModel.rolloutDistribution.isEmpty && !viewModel.sqliteDistribution.isEmpty {
                Divider()
            }

            if !viewModel.sqliteDistribution.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Database")
                        .font(.subheadline.weight(.medium))
                    distributionTable(viewModel.sqliteDistribution)
                }
            }

            if viewModel.rolloutDistribution.isEmpty && viewModel.sqliteDistribution.isEmpty {
                Text("No session data found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func distributionTable(_ items: [ProviderDistribution]) -> some View {
        VStack(spacing: 2) {
            ForEach(items, id: \.provider) { item in
                HStack {
                    Text(item.provider)
                        .font(.caption.monospaced())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("sessions: \(item.sessionCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)
                    Text("archived: \(item.archivedCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .trailing)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Sync

    private var syncSection: some View {
        section("Sync") {
            HStack {
                Text("Target:")
                    .font(.subheadline)
                Picker("", selection: $viewModel.selectedSyncTarget) {
                    ForEach(allProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 160)

                Spacer()

                Button("Sync Now") {
                    Task { await viewModel.syncNow() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.isSyncing)
            }

            Divider()

            HStack {
                Text("Switch to:")
                    .font(.subheadline)
                Picker("", selection: $viewModel.selectedSwitchTarget) {
                    ForEach(viewModel.configuredProviders, id: \.self) { provider in
                        Text(provider).tag(provider)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 160)

                Spacer()

                Button("Switch & Sync") {
                    Task { await viewModel.switchAndSync() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isSyncing || viewModel.selectedSwitchTarget == viewModel.currentProvider)
            }

            if viewModel.isSyncing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Backups

    private var backupsSection: some View {
        section("Backups") {
            if viewModel.backups.isEmpty {
                Text("No backups found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(viewModel.backups.count) backups (\(formattedSize(viewModel.backupTotalSize)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    ForEach(viewModel.backups) { backup in
                        HStack {
                            Image(systemName: viewModel.selectedBackupID == backup.id ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(viewModel.selectedBackupID == backup.id ? .accentColor : .secondary)
                                .font(.system(size: 14))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(formattedDate(backup.timestamp))
                                    .font(.caption.weight(.medium))
                                Text("\(backup.targetProvider) - \(formattedSize(backup.totalSize))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(viewModel.selectedBackupID == backup.id ? Color.accentColor.opacity(0.08) : Color.clear)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectBackup(id: viewModel.selectedBackupID == backup.id ? nil : backup.id)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button("Restore Selected") {
                        Task { await viewModel.restoreSelectedBackup() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.selectedBackupID == nil || viewModel.isSyncing)

                    Button("Prune Old") {
                        Task { await viewModel.pruneOldBackups() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(viewModel.backups.count <= 5 || viewModel.isSyncing)
                }
            }
        }
    }

    // MARK: - Helpers

    private var allProviders: [String] {
        var providers = Set(viewModel.configuredProviders)
        for dist in viewModel.rolloutDistribution {
            providers.insert(dist.provider)
        }
        for dist in viewModel.sqliteDistribution {
            providers.insert(dist.provider)
        }
        providers.remove("(missing)")
        return Array(providers).sorted()
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        } label: {
            Text(title)
                .font(.headline)
        }
    }

    private func formattedSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
