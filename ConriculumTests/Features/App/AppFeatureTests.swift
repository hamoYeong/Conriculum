import ComposableArchitecture
import Testing

@testable import Conriculum

@MainActor
struct AppFeatureTests {
    @Test
    func initialRouteIsHome() {
        #expect(AppFeature.State().route == .home)
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
