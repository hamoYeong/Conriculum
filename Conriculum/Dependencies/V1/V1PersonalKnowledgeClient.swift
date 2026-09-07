import ComposableArchitecture

@DependencyClient
struct V1PersonalKnowledgeClient: Sendable {
    var loadAllRevisions: @Sendable () async throws -> [PersonalConceptRevision]
    var loadRevisions: @Sendable (
        _ conceptID: KnowledgeConceptID
    ) async throws -> [PersonalConceptRevision]
    var saveRevision: @Sendable (_ revision: PersonalConceptRevision) async throws -> Void

    var loadAllRelations: @Sendable () async throws -> [PersonalKnowledgeRelation]
    var loadRelations: @Sendable (
        _ conceptID: KnowledgeConceptID
    ) async throws -> [PersonalKnowledgeRelation]
    var saveRelation: @Sendable (_ relation: PersonalKnowledgeRelation) async throws -> Void
}

extension V1PersonalKnowledgeClient: DependencyKey {
    static let liveValue = Self.live(resolveStore: {
        try await PersistenceEnvironmentRegistry.live().userDataStore
    })
}

extension V1PersonalKnowledgeClient: TestDependencyKey {
    static let previewValue = Self.live(resolveStore: {
        try await PersistenceEnvironmentRegistry.preview().userDataStore
    })
    static let testValue = Self.live(resolveStore: {
        try await PersistenceEnvironmentRegistry.test().userDataStore
    })
}

extension V1PersonalKnowledgeClient {
    static func live(store: UserDataStore) -> Self {
        live(resolveStore: { store })
    }

    private static func live(
        resolveStore: @escaping @Sendable () async throws -> UserDataStore
    ) -> Self {
        Self(
            loadAllRevisions: {
                let store = try await resolveStore()
                return try await store.loadAllRevisions()
            },
            loadRevisions: { conceptID in
                let store = try await resolveStore()
                return try await store.loadRevisions(conceptID: conceptID)
            },
            saveRevision: { revision in
                let store = try await resolveStore()
                try await store.saveRevision(revision)
            },
            loadAllRelations: {
                let store = try await resolveStore()
                return try await store.loadAllRelations()
            },
            loadRelations: { conceptID in
                let store = try await resolveStore()
                return try await store.loadRelations(conceptID: conceptID)
            },
            saveRelation: { relation in
                let store = try await resolveStore()
                try await store.saveRelation(relation)
            }
        )
    }
}

extension DependencyValues {
    var v1PersonalKnowledgeClient: V1PersonalKnowledgeClient {
        get { self[V1PersonalKnowledgeClient.self] }
        set { self[V1PersonalKnowledgeClient.self] = newValue }
    }
}
