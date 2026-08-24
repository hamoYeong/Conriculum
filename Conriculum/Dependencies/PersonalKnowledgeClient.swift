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
    static let liveValue = Self.live(resolveStore: {
        try await PersistenceEnvironmentRegistry.live().userDataStore
    })
}

extension PersonalKnowledgeClient: TestDependencyKey {
    static let previewValue = Self.live(resolveStore: {
        try await PersistenceEnvironmentRegistry.preview().userDataStore
    })
    static let testValue = Self.live(resolveStore: {
        try await PersistenceEnvironmentRegistry.test().userDataStore
    })
}

extension PersonalKnowledgeClient {
    static func live(store: UserDataStore) -> Self {
        live(resolveStore: { store })
    }

    private static func live(
        resolveStore: @escaping @Sendable () async throws -> UserDataStore
    ) -> Self {
        Self(
            loadRevisions: { conceptID in
                let store = try await resolveStore()
                return try await store.loadRevisions(conceptID: conceptID)
            },
            saveRevision: { revision in
                let store = try await resolveStore()
                try await store.saveRevision(revision)
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
    var personalKnowledgeClient: PersonalKnowledgeClient {
        get { self[PersonalKnowledgeClient.self] }
        set { self[PersonalKnowledgeClient.self] = newValue }
    }
}
