import ComposableArchitecture

@DependencyClient
struct LearningRecordClient: Sendable {
    var loadProgress: @Sendable (_ chapterID: ChapterID) async throws -> LearningProgress?
    var saveProgress: @Sendable (_ progress: LearningProgress) async throws -> Void

    var loadResponses: @Sendable (_ pageID: LearningPageID) async throws -> [ActivityResponse]
    var saveResponse: @Sendable (_ response: ActivityResponse) async throws -> Void

    var loadEvidence: @Sendable (_ pageID: LearningPageID) async throws -> [LearningEvidence]
    var saveEvidence: @Sendable (_ evidence: LearningEvidence) async throws -> Void
}

extension LearningRecordClient: DependencyKey {
    static let liveValue = Self.live(resolveStore: {
        try await PersistenceEnvironmentRegistry.live().userDataStore
    })
}

extension LearningRecordClient: TestDependencyKey {
    static let previewValue = Self.live(resolveStore: {
        try await PersistenceEnvironmentRegistry.preview().userDataStore
    })
    static let testValue = Self.live(resolveStore: {
        try await PersistenceEnvironmentRegistry.test().userDataStore
    })
}

extension LearningRecordClient {
    static func live(store: UserDataStore) -> Self {
        live(resolveStore: { store })
    }

    private static func live(
        resolveStore: @escaping @Sendable () async throws -> UserDataStore
    ) -> Self {
        Self(
            loadProgress: { chapterID in
                let store = try await resolveStore()
                return try await store.loadProgress(chapterID: chapterID)
            },
            saveProgress: { progress in
                let store = try await resolveStore()
                try await store.saveProgress(progress)
            },
            loadResponses: { pageID in
                let store = try await resolveStore()
                return try await store.loadResponses(pageID: pageID)
            },
            saveResponse: { response in
                let store = try await resolveStore()
                try await store.saveResponse(response)
            },
            loadEvidence: { pageID in
                let store = try await resolveStore()
                return try await store.loadEvidence(pageID: pageID)
            },
            saveEvidence: { evidence in
                let store = try await resolveStore()
                try await store.saveEvidence(evidence)
            }
        )
    }
}

extension DependencyValues {
    var learningRecordClient: LearningRecordClient {
        get { self[LearningRecordClient.self] }
        set { self[LearningRecordClient.self] = newValue }
    }
}
