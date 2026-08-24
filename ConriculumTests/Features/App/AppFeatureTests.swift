import ComposableArchitecture
import Testing

@testable import Conriculum

@MainActor
struct AppFeatureTests {
    @Test
    func initialRouteIsHomeAndLoadsChapterEntry() async throws {
        let chapter = try ContentResourceDecoder().decode(
            Chapter.self,
            from: .chapter02
        )
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.curriculumClient.loadChapter = { _ in chapter }
            $0.learningRecordClient.loadProgress = { _ in nil }
        }

        #expect(store.state.route == .home)

        await store.send(.home(.task)) {
            $0.home.isLoading = true
        }
        await store.receive(
            .home(.loadResponse(.loaded(
                HomeFeature.ChapterEntry(
                    chapterID: chapter.id,
                    startPageID: chapter.overview.id,
                    resumePageID: nil
                )
            )))
        ) {
            $0.home.isLoading = false
            $0.home.chapterEntry = HomeFeature.ChapterEntry(
                chapterID: chapter.id,
                startPageID: chapter.overview.id,
                resumePageID: nil
            )
        }
    }

    @Test
    func startDelegatesTheOverviewRoute() async {
        let entry = HomeFeature.ChapterEntry(
            chapterID: AppFeature.chapter02ID,
            startPageID: "chapter-02-overview",
            resumePageID: nil
        )
        var initialState = AppFeature.State()
        initialState.home.chapterEntry = entry
        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.home(.startButtonTapped))
        await store.receive(.home(.delegate(.chapterRequested(
            chapterID: entry.chapterID,
            pageID: entry.startPageID
        )))) {
            $0.route = .learningWorkspace(
                chapterID: entry.chapterID,
                pageID: entry.startPageID
            )
        }
    }

    @Test
    func resumeDelegatesTheSavedPageRoute() async {
        let entry = HomeFeature.ChapterEntry(
            chapterID: AppFeature.chapter02ID,
            startPageID: "chapter-02-overview",
            resumePageID: "chapter-02-page-04"
        )
        var initialState = AppFeature.State()
        initialState.home.chapterEntry = entry
        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.home(.resumeButtonTapped))
        await store.receive(.home(.delegate(.chapterRequested(
            chapterID: entry.chapterID,
            pageID: "chapter-02-page-04"
        )))) {
            $0.route = .learningWorkspace(
                chapterID: entry.chapterID,
                pageID: "chapter-02-page-04"
            )
        }
    }
}
