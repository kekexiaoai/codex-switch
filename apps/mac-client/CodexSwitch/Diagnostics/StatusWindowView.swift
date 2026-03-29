import SwiftUI

public struct StatusWindowView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Status Page")
                .font(.title2.weight(.semibold))
            StatusView()
            Spacer()
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 240)
    }
}
