import ComposableArchitecture

@DependencyClient
struct KnowledgeCatalogClient: Sendable {
    var loadCatalog: @Sendable () async throws -> KnowledgeCatalog
    var loadConcept: @Sendable (_ conceptID: KnowledgeConceptID) async throws -> KnowledgeConcept
    var loadRelations: @Sendable (
        _ conceptID: KnowledgeConceptID
    ) async throws -> [KnowledgeRelation]
}

extension KnowledgeCatalogClient: DependencyKey {
    static let liveValue = Self.live(store: BundledKnowledgeEnvironment.live)
}

extension KnowledgeCatalogClient: TestDependencyKey {
    static let previewValue = Self.live(store: BundledKnowledgeEnvironment.preview)
    static let testValue = Self.live(store: BundledKnowledgeEnvironment.test)
}

extension KnowledgeCatalogClient {
    static func live(store: BundledContentStore) -> Self {
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
    var knowledgeCatalogClient: KnowledgeCatalogClient {
        get { self[KnowledgeCatalogClient.self] }
        set { self[KnowledgeCatalogClient.self] = newValue }
    }
}

private enum BundledKnowledgeEnvironment {
    static let live = BundledContentStore()
    static let preview = BundledContentStore()
    static let test = BundledContentStore()
}
