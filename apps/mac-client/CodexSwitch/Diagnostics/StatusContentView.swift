import SwiftUI

public struct StatusContentView: View {
    private let snapshot: StatusSnapshot
    private let preferredLanguages: [String]?

    public init(snapshot: StatusSnapshot, preferredLanguages: [String]? = nil) {
        self.snapshot = snapshot
        self.preferredLanguages = preferredLanguages
    }

    public var body: some View {
        StatusWindowView(snapshot: snapshot, preferredLanguages: preferredLanguages)
    }
}
