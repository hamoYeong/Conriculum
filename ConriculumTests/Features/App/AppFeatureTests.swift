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
    func supportedChapterAndHomeTransitions() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.chapterRequested(id: AppFeature.chapter02ID)) {
            $0.route = .learningWorkspace(chapterID: AppFeature.chapter02ID)
        }

        await store.send(.homeRequested) {
            $0.route = .home
        }
    }

    @Test
    func unknownChapterIsIgnored() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.chapterRequested(id: "chapter-unknown"))
    }

    @Test
    func duplicateRouteRequestDoesNotCreateAdditionalState() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.chapterRequested(id: AppFeature.chapter02ID)) {
            $0.route = .learningWorkspace(chapterID: AppFeature.chapter02ID)
        }
        await store.send(.chapterRequested(id: AppFeature.chapter02ID))
    }
}
