import SwiftUI

public struct StatusContentView: View {
    @State private var snapshot: StatusSnapshot
    private let loadSnapshot: (() async -> StatusSnapshot)?
    private let preferredLanguages: [String]?

    public init(snapshot: StatusSnapshot, preferredLanguages: [String]? = nil) {
        _snapshot = State(initialValue: snapshot)
        self.loadSnapshot = nil
        self.preferredLanguages = preferredLanguages
    }

    public init(snapshotLoader: StatusSnapshotLoader?, preferredLanguages: [String]? = nil) {
        _snapshot = State(initialValue: .preview)
        self.loadSnapshot = snapshotLoader.map { loader in
            { await loader.loadSnapshot() }
        }
        self.preferredLanguages = preferredLanguages
    }

    public var body: some View {
        StatusWindowView(snapshot: snapshot, preferredLanguages: preferredLanguages)
            .task {
                guard let loadSnapshot else {
                    return
                }

                snapshot = await loadSnapshot()
            }
    }
}
