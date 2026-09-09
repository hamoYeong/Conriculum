import ComposableArchitecture

@DependencyClient
struct V1CurriculumClient: Sendable {
    var loadChapters: @Sendable () async throws -> [V1Chapter]
    var loadChapter: @Sendable (_ chapterID: ChapterID) async throws -> V1Chapter
    var loadPage: @Sendable (
        _ chapterID: ChapterID,
        _ pageID: LearningPageID
    ) async throws -> V1LearningPage
}

extension V1CurriculumClient: DependencyKey {
    static let liveValue = Self.live(store: BundledContentEnvironment.live)
}

extension V1CurriculumClient: TestDependencyKey {
    static let previewValue = Self.live(store: BundledContentEnvironment.preview)
    static let testValue = Self.live(store: BundledContentEnvironment.test)
}

extension V1CurriculumClient {
    static func live(store: V1BundledContentStore) -> Self {
        Self(
            loadChapters: {
                try await store.loadChapters()
            },
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
    var v1CurriculumClient: V1CurriculumClient {
        get { self[V1CurriculumClient.self] }
        set { self[V1CurriculumClient.self] = newValue }
    }
}

private enum BundledContentEnvironment {
    static let live = V1BundledContentStore()
    static let preview = V1BundledContentStore()
    static let test = V1BundledContentStore()
}
