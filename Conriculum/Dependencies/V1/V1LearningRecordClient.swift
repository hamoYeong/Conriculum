import ComposableArchitecture

@DependencyClient
struct V1LearningRecordClient: Sendable {
    var loadProgress: @Sendable (_ chapterID: ChapterID) async throws -> V1LearningProgress?
    var saveProgress: @Sendable (_ progress: V1LearningProgress) async throws -> Void

    var loadResponses: @Sendable (_ pageID: LearningPageID) async throws -> [V1ActivityResponse]
    var saveResponse: @Sendable (_ response: V1ActivityResponse) async throws -> Void

    var loadEvidence: @Sendable (_ pageID: LearningPageID) async throws -> [V1LearningEvidence]
    var saveEvidence: @Sendable (_ evidence: V1LearningEvidence) async throws -> Void
    var recordPageVisit: @Sendable (_ chapter: V1Chapter, _ pageID: LearningPageID) async throws -> Void
}

extension V1LearningRecordClient: DependencyKey {
    static let liveValue = Self.live(resolveStore: {
        try await V1PersistenceEnvironmentRegistry.live().userDataStore
    })
}

extension V1LearningRecordClient: TestDependencyKey {
    static let previewValue = Self.live(resolveStore: {
        try await V1PersistenceEnvironmentRegistry.preview().userDataStore
    })
    static let testValue = Self.live(resolveStore: {
        try await V1PersistenceEnvironmentRegistry.test().userDataStore
    })
}

extension V1LearningRecordClient {
    static func live(store: V1UserDataStore) -> Self {
        live(resolveStore: { store })
    }

    private static func live(
        resolveStore: @escaping @Sendable () async throws -> V1UserDataStore
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
            },
            recordPageVisit: { chapter, pageID in
                let store = try await resolveStore()
                try await store.recordPageVisit(chapter: chapter, pageID: pageID)
            }
        )
    }
}

extension DependencyValues {
    var v1LearningRecordClient: V1LearningRecordClient {
        get { self[V1LearningRecordClient.self] }
        set { self[V1LearningRecordClient.self] = newValue }
    }
}
