import ComposableArchitecture

@DependencyClient
struct V1KnowledgeCatalogClient: Sendable {
    var loadCatalog: @Sendable () async throws -> KnowledgeCatalog
    var loadConcept: @Sendable (_ conceptID: KnowledgeConceptID) async throws -> KnowledgeConcept
    var loadRelations: @Sendable (
        _ conceptID: KnowledgeConceptID
    ) async throws -> [KnowledgeRelation]
}

extension V1KnowledgeCatalogClient: DependencyKey {
    static let liveValue = Self.live(store: BundledKnowledgeEnvironment.live)
}

extension V1KnowledgeCatalogClient: TestDependencyKey {
    static let previewValue = Self.live(store: BundledKnowledgeEnvironment.preview)
    static let testValue = Self.live(store: BundledKnowledgeEnvironment.test)
}

extension V1KnowledgeCatalogClient {
    static func live(store: V1BundledContentStore) -> Self {
        Self(
            loadCatalog: {
                try await store.loadCatalog()
            },
            loadConcept: { conceptID in
                try await store.loadConcept(conceptID)
            },
            loadRelations: { conceptID in
                try await store.loadRelations(conceptID)
            }
        )
    }
}

extension DependencyValues {
    var v1KnowledgeCatalogClient: V1KnowledgeCatalogClient {
        get { self[V1KnowledgeCatalogClient.self] }
        set { self[V1KnowledgeCatalogClient.self] = newValue }
    }
}

private enum BundledKnowledgeEnvironment {
    static let live = V1BundledContentStore()
    static let preview = V1BundledContentStore()
    static let test = V1BundledContentStore()
}
