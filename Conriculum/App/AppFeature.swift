import ComposableArchitecture

@Reducer
struct AppFeature {
    static let chapter02ID = Chapter02.id

    @ObservableState
    struct State: Equatable {
        var route: Route = .home
        var home = HomeFeature.State()
        var workspace: LearningWorkspaceFeature.State?
    }

    enum Route: Equatable {
        case home
        case learningWorkspace(chapterID: ChapterID)
    }

    enum Action: Equatable {
        case home(HomeFeature.Action)
        case workspace(LearningWorkspaceFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case let .home(.delegate(.chapterRequested(chapterID, pageID))):
                guard chapterID == Self.chapter02ID else { return .none }
                state.workspace = LearningWorkspaceFeature.State(
                    chapterID: chapterID,
                    pageID: pageID,
                    pendingPersonalizationReviews: state.home
                        .pendingPersonalizationReviews
                )
                state.route = .learningWorkspace(chapterID: chapterID)
                return .none

            case .workspace(.delegate(.homeRequested)):
                let pendingReviews = state.workspace?
                    .pendingPersonalizationReviews ?? []
                state.route = .home
                return .send(.home(.workspaceReturned(pendingReviews)))

            case .home, .workspace:
                return .none
            }
        }
        .ifLet(\.workspace, action: \.workspace) {
            LearningWorkspaceFeature()
        }
    }
}
