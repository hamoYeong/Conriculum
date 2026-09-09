import ComposableArchitecture
import Foundation

@DependencyClient
struct ProgressClient: Sendable {
    var load: @Sendable () async throws -> CourseProgress = { .empty }
    var save: @Sendable (_ progress: CourseProgress) async throws -> Void
}

extension ProgressClient: DependencyKey {
    static let liveValue = Self.live(
        resolveStore: {
            try await PersistenceEnvironmentRegistry.live().courseProgressStore
        },
        legacyStore: .standard
    )
}

extension ProgressClient: TestDependencyKey {
    static let previewValue = Self()
    static let testValue = Self()
}

extension ProgressClient {
    @MainActor
    static func live(
        store: CourseProgressStore,
        legacyStore: UserDefaults? = nil
    ) -> Self {
        live(resolveStore: { store }, legacyStore: legacyStore)
    }

    @MainActor
    private static func live(
        resolveStore: @escaping @Sendable () async throws -> CourseProgressStore,
        legacyStore: UserDefaults?
    ) -> Self {
        let legacyStorage = legacyStore.map(LegacyProgressStorage.init(store:))
        return Self(
            load: {
                let store = try await resolveStore()
                if let progress = try await store.load() {
                    return progress
                }
                guard let progress = try legacyStorage?.load() else {
                    return .empty
                }
                try await store.save(progress)
                return progress
            },
            save: { progress in
                let store = try await resolveStore()
                try await store.save(progress)
            }
        )
    }
}

extension DependencyValues {
    var progressClient: ProgressClient {
        get { self[ProgressClient.self] }
        set { self[ProgressClient.self] = newValue }
    }
}

private final class LegacyProgressStorage: @unchecked Sendable {
    private let store: UserDefaults
    private let key = "learning.progress.v2"
    private let lock = NSLock()

    init(store: UserDefaults) {
        self.store = store
    }

    func load() throws -> CourseProgress? {
        try lock.withLock {
            guard let data = store.data(forKey: key) else { return nil }
            return try JSONDecoder().decode(CourseProgress.self, from: data)
        }
    }
}
