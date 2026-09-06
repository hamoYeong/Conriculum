import ComposableArchitecture

@DependencyClient
struct V2ContentClient: Sendable {
    var loadManifest: @Sendable () async throws -> V2ContentManifest
    var loadPage: @Sendable (_ id: VersionedContentID) async throws -> V2LearningPage
    var loadKnowledgeCatalog: @Sendable () async throws -> KnowledgeCatalog
}

extension V2ContentClient: DependencyKey {
    static let liveValue = Self.live(store: V2ContentEnvironment.live)
}

extension V2ContentClient: TestDependencyKey {
    static let previewValue = Self.live(store: V2ContentEnvironment.preview)
    static let testValue = Self()
}

extension V2ContentClient {
    static func live(store: V2BundledContentStore) -> Self {
        Self(
            loadManifest: { try await store.loadManifest() },
            loadPage: { try await store.loadPage(id: $0) },
            loadKnowledgeCatalog: { try await store.loadKnowledgeCatalog() }
        )
    }
}

extension DependencyValues {
    var v2ContentClient: V2ContentClient {
        get { self[V2ContentClient.self] }
        set { self[V2ContentClient.self] = newValue }
    }
}

@MainActor
private enum V2ContentEnvironment {
    static let live = V2BundledContentStore()
    static let preview = V2BundledContentStore()
}
