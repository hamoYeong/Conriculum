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
    static let liveValue = Self.live(store: BundledContentEnvironment.live)
}

extension CurriculumClient: TestDependencyKey {
    static let previewValue = Self.live(store: BundledContentEnvironment.preview)
    static let testValue = Self.live(store: BundledContentEnvironment.test)
}

extension CurriculumClient {
    static func live(store: BundledContentStore) -> Self {
        Self(
            loadChapter: { chapterID in
                try await store.loadChapter(chapterID)
            },
            loadPage: { chapterID, pageID in
                try await store.loadPage(
                    chapterID: chapterID,
                    pageID: pageID
                )
            }
        )
    }
}

extension DependencyValues {
    var curriculumClient: CurriculumClient {
        get { self[CurriculumClient.self] }
        set { self[CurriculumClient.self] = newValue }
    }
}

private enum BundledContentEnvironment {
    static let live = BundledContentStore()
    static let preview = BundledContentStore()
    static let test = BundledContentStore()
}
