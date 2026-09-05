import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var route: Route = .home
        var home = HomeFeature.State()
        var workspace: LearningWorkspaceFeature.State?
        var knowledgeSystem: KnowledgeSystemFeature.State?
    }

    enum Route: Equatable {
        case home
        case learningWorkspace(chapterID: ChapterID)
        case knowledgeSystem
    }

    enum Action: Equatable {
        case home(HomeFeature.Action)
        case workspace(LearningWorkspaceFeature.Action)
        case knowledgeSystem(KnowledgeSystemFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case let .workspace(.delegate(.chapterRequested(chapterID, pageID))):
                let pending = state.workspace?.pendingPersonalizationReviews ?? []
                state.workspace = LearningWorkspaceFeature.State(
                    chapterID: chapterID, pageID: pageID,
                    pendingPersonalizationReviews: pending
                )
                state.route = .learningWorkspace(chapterID: chapterID)
                return .none

            case let .home(.delegate(.chapterRequested(chapterID, pageID))):
                state.workspace = LearningWorkspaceFeature.State(
                    chapterID: chapterID,
                    pageID: pageID,
                    pendingPersonalizationReviews: state.home
                        .pendingPersonalizationReviews
                )
                state.route = .learningWorkspace(chapterID: chapterID)
                return .none

            case .home(.delegate(.knowledgeSystemRequested)):
                state.knowledgeSystem = KnowledgeSystemFeature.State()
                state.route = .knowledgeSystem
                return .none

            case .workspace(.delegate(.homeRequested)):
                let pendingReviews = state.workspace?
                    .pendingPersonalizationReviews ?? []
                state.route = .home
                return .send(.home(.workspaceReturned(pendingReviews)))

            case .knowledgeSystem(.delegate(.homeRequested)):
                state.route = .home
                state.knowledgeSystem = nil
                return .none

            case let .knowledgeSystem(.delegate(.learningRequested(
                chapterID,
                pageID
            ))):
                state.knowledgeSystem = nil
                state.workspace = LearningWorkspaceFeature.State(
                    chapterID: chapterID,
                    pageID: pageID,
                    pendingPersonalizationReviews: state.home
                        .pendingPersonalizationReviews
                )
                state.route = .learningWorkspace(chapterID: chapterID)
                return .none

            case .home, .workspace, .knowledgeSystem:
                return .none
            }
        }
        .ifLet(\.workspace, action: \.workspace) {
            LearningWorkspaceFeature()
        }
        .ifLet(\.knowledgeSystem, action: \.knowledgeSystem) {
            KnowledgeSystemFeature()
        }
    }
}
