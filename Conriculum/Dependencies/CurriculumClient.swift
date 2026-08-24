import ComposableArchitecture

@DependencyClient
struct CurriculumClient: Sendable {
    var loadChapter: @Sendable (_ chapterID: ChapterID) async throws -> Chapter
    var loadPage: @Sendable (
        _ chapterID: ChapterID,
        _ pageID: LearningPageID
    ) async throws -> LearningPage
}

extension CurriculumClient: DependencyKey {
    static let liveValue = Self()
}

extension CurriculumClient: TestDependencyKey {
    static let previewValue = Self()
    static let testValue = Self()
}

extension DependencyValues {
    var curriculumClient: CurriculumClient {
        get { self[CurriculumClient.self] }
        set { self[CurriculumClient.self] = newValue }
    }
}
