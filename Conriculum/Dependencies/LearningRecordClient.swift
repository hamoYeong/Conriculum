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
    static let liveValue = Self()
}

extension LearningRecordClient: TestDependencyKey {
    static let previewValue = Self(
        loadProgress: { _ in nil },
        saveProgress: { _ in },
        loadResponses: { _ in [] },
        saveResponse: { _ in },
        loadEvidence: { _ in [] },
        saveEvidence: { _ in }
    )
    static let testValue = Self()
}

extension DependencyValues {
    var learningRecordClient: LearningRecordClient {
        get { self[LearningRecordClient.self] }
        set { self[LearningRecordClient.self] = newValue }
    }
}
