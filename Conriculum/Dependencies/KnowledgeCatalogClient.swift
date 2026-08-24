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
    static let liveValue = Self()
}

extension KnowledgeCatalogClient: TestDependencyKey {
    static let previewValue = Self()
    static let testValue = Self()
}

extension DependencyValues {
    var knowledgeCatalogClient: KnowledgeCatalogClient {
        get { self[KnowledgeCatalogClient.self] }
        set { self[KnowledgeCatalogClient.self] = newValue }
    }
}
