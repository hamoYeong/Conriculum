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
        }
    )
}

extension ProgressClient: TestDependencyKey {
    static let previewValue = Self()
    static let testValue = Self()
}

extension ProgressClient {
    @MainActor
    static func live(store: CourseProgressStore) -> Self {
        live(resolveStore: { store })
    }

    @MainActor
    private static func live(
        resolveStore: @escaping @Sendable () async throws -> CourseProgressStore
    ) -> Self {
        return Self(
            load: {
                let store = try await resolveStore()
                return try await store.load() ?? .empty
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
