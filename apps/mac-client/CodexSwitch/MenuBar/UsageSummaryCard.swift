import SwiftUI

public struct UsageSummaryCard: View {
    private let summary: UsageSummaryModel

    public init(summary: UsageSummaryModel) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(summary.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(summary.percentUsed)%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            ProgressView(value: Double(summary.percentUsed), total: 100)
                .tint(Color(nsColor: .systemTeal))

            Text(summary.resetText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
