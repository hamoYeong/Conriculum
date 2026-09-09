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
    func pageRequestOpensLearningRoute() async {
        let pageID = "s1.c1.p1"
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.home(.delegate(.pageRequested(pageID)))) {
            $0.learning = LearningFeature.State(pageID: pageID)
            $0.route = .learning(pageID: pageID)
        }
    }

    @Test
    func homeKnowledgeRequestOpensKnowledgeSystem() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.home(.knowledgeSystemButtonTapped))
        await store.receive(.home(.delegate(.knowledgeSystemRequested))) {
            $0.knowledgeSystem = KnowledgeSystemFeature.State()
            $0.route = .knowledgeSystem
        }
    }

    @Test
    func knowledgeSystemBackReturnsHomeAndReleasesItsState() async {
        var initialState = AppFeature.State()
        initialState.route = .knowledgeSystem
        initialState.knowledgeSystem = KnowledgeSystemFeature.State()
        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.knowledgeSystem(.homeButtonTapped))
        await store.receive(.knowledgeSystem(.delegate(.homeRequested))) {
            $0.route = .home
            $0.knowledgeSystem = nil
        }
    }

    @Test
    func knowledgeRevisitOpensLearningAndReleasesKnowledgeState() async {
        let pageID = "s2.c1.p1"
        var initialState = AppFeature.State()
        initialState.route = .knowledgeSystem
        initialState.knowledgeSystem = KnowledgeSystemFeature.State()
        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.knowledgeSystem(.delegate(.learningRequested(pageID)))) {
            $0.knowledgeSystem = nil
            $0.learning = LearningFeature.State(pageID: pageID)
            $0.route = .learning(pageID: pageID)
        }
    }
}
