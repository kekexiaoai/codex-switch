import SwiftUI

public struct MainWindowView: View {
    @ObservedObject private var viewModel: MainWindowViewModel
    private let accountsContent: AnyView
    private let providerSyncContent: AnyView
    private let settingsContent: AnyView
    private let statusContent: AnyView

    public init(
        viewModel: MainWindowViewModel,
        accountsContent: AnyView = AnyView(EmptyView()),
        providerSyncContent: AnyView = AnyView(EmptyView()),
        settingsContent: AnyView = AnyView(EmptyView()),
        statusContent: AnyView = AnyView(EmptyView())
    ) {
        self.viewModel = viewModel
        self.accountsContent = accountsContent
        self.providerSyncContent = providerSyncContent
        self.settingsContent = settingsContent
        self.statusContent = statusContent
    }

    public var tabLabels: [String] {
        MainWindowTab.allCases.map(\.title)
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $viewModel.selectedTab) {
                ForEach(MainWindowTab.allCases, id: \.self) { tab in
                    Text(tab.title)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(20)

            Divider()

            currentContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var currentContent: some View {
        switch viewModel.selectedTab {
        case .accounts:
            accountsContent
        case .providerSync:
            providerSyncContent
        case .settings:
            settingsContent
        case .status:
            statusContent
        }
    }
}
