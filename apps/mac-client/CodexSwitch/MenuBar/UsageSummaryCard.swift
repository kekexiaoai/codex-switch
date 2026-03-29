import SwiftUI

public struct UsageSummaryCard: View {
    private let summary: UsageSummaryModel

    public init(summary: UsageSummaryModel) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.title)
                    .font(.headline)
                Spacer()
                Text("\(summary.percentUsed)%")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: Double(summary.percentUsed), total: 100)
                .tint(Color(nsColor: .systemTeal))

            Text(summary.resetText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
