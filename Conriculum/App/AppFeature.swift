import ComposableArchitecture

@Reducer
struct AppFeature {
    static let chapter02ID = Chapter02.id

    @ObservableState
    struct State: Equatable {
        var route: Route = .home
        var home = HomeFeature.State()
    }

    enum Route: Equatable {
        case home
        case learningWorkspace(
            chapterID: ChapterID,
            pageID: LearningPageID
        )
    }

    enum Action: Equatable {
        case home(HomeFeature.Action)
        case workspaceHomeButtonTapped
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case let .home(.delegate(.chapterRequested(chapterID, pageID))):
                guard chapterID == Self.chapter02ID else { return .none }
                state.route = .learningWorkspace(
                    chapterID: chapterID,
                    pageID: pageID
                )
                return .none

            case .workspaceHomeButtonTapped:
                state.route = .home
                return .send(.home(.reloadRequested))

            case .home:
                return .none
            }
        }
    }
}
