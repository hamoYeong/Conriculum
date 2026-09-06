import ComposableArchitecture
import Foundation

struct V2Progress: Codable, Equatable, Sendable {
    var lastVisitedPageID: String?
    var completedPageIDs: Set<String>

    nonisolated static let empty = Self(lastVisitedPageID: nil, completedPageIDs: [])
}

@DependencyClient
struct V2ProgressClient: Sendable {
    var load: @Sendable () async throws -> V2Progress = { .empty }
    var save: @Sendable (_ progress: V2Progress) async throws -> Void
}

extension V2ProgressClient: DependencyKey {
    static let liveValue = Self.live(store: .standard)
}

extension V2ProgressClient: TestDependencyKey {
    static let previewValue = Self()
    static let testValue = Self()
}

extension V2ProgressClient {
    static func live(store: UserDefaults) -> Self {
        let storage = V2ProgressStorage(store: store)
        return Self(
            load: { try storage.load() },
            save: { try storage.save($0) }
        )
    }
}

extension DependencyValues {
    var v2ProgressClient: V2ProgressClient {
        get { self[V2ProgressClient.self] }
        set { self[V2ProgressClient.self] = newValue }
    }
}

private final class V2ProgressStorage: @unchecked Sendable {
    private let store: UserDefaults
    private let key = "learning.progress.v2"
    private let lock = NSLock()

    init(store: UserDefaults) {
        self.store = store
    }

    func load() throws -> V2Progress {
        try lock.withLock {
            guard let data = store.data(forKey: key) else { return .empty }
            return try JSONDecoder().decode(V2Progress.self, from: data)
        }
    }

    func save(_ progress: V2Progress) throws {
        let data = try JSONEncoder().encode(progress)
        lock.withLock { store.set(data, forKey: key) }
    }
}
