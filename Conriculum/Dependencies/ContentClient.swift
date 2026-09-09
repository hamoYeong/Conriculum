import ComposableArchitecture

@DependencyClient
struct ContentClient: Sendable {
    var loadManifest: @Sendable () async throws -> ContentManifest
    var loadPage: @Sendable (_ id: String) async throws -> LessonPage
    var loadKnowledgeCatalog: @Sendable () async throws -> KnowledgeCatalog
}

extension ContentClient: DependencyKey {
    static let liveValue = Self.live(store: ContentEnvironment.live)
}

extension ContentClient: TestDependencyKey {
    static let previewValue = Self.live(store: ContentEnvironment.preview)
    static let testValue = Self()
}

extension ContentClient {
    static func live(store: BundledContentStore) -> Self {
        Self(
            loadManifest: { try await store.loadManifest() },
            loadPage: { try await store.loadPage(id: $0) },
            loadKnowledgeCatalog: { try await store.loadKnowledgeCatalog() }
        )
    }
}

extension DependencyValues {
    var contentClient: ContentClient {
        get { self[ContentClient.self] }
        set { self[ContentClient.self] = newValue }
    }
}

@MainActor
private enum ContentEnvironment {
    static let live = BundledContentStore()
    static let preview = BundledContentStore()
}
