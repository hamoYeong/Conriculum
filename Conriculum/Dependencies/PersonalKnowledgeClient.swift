import ComposableArchitecture

@DependencyClient
struct PersonalKnowledgeClient: Sendable {
    var loadRevisions: @Sendable (
        _ conceptID: KnowledgeConceptID
    ) async throws -> [PersonalConceptRevision]
    var saveRevision: @Sendable (_ revision: PersonalConceptRevision) async throws -> Void

    var loadRelations: @Sendable (
        _ conceptID: KnowledgeConceptID
    ) async throws -> [PersonalKnowledgeRelation]
    var saveRelation: @Sendable (_ relation: PersonalKnowledgeRelation) async throws -> Void
}

extension PersonalKnowledgeClient: DependencyKey {
    static let liveValue = Self()
}

extension PersonalKnowledgeClient: TestDependencyKey {
    static let previewValue = Self(
        loadRevisions: { _ in [] },
        saveRevision: { _ in },
        loadRelations: { _ in [] },
        saveRelation: { _ in }
    )
    static let testValue = Self()
}

extension DependencyValues {
    var personalKnowledgeClient: PersonalKnowledgeClient {
        get { self[PersonalKnowledgeClient.self] }
        set { self[PersonalKnowledgeClient.self] = newValue }
    }
}
