import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var route: Route = .home
        var home = HomeFeature.State()
        var v1Workspace: V1LearningWorkspaceFeature.State?
        var learning: LearningFeature.State?
        var knowledgeSystem: KnowledgeSystemFeature.State?
    }

    enum Route: Equatable {
        case home
        case v1Learning(chapterID: ChapterID)
        case learning(pageID: String)
        case knowledgeSystem
    }

    enum Action: Equatable {
        case home(HomeFeature.Action)
        case v1Workspace(V1LearningWorkspaceFeature.Action)
        case learning(LearningFeature.Action)
        case knowledgeSystem(KnowledgeSystemFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case let .v1Workspace(.delegate(.v1ChapterRequested(chapterID, pageID))):
                let pending = state.v1Workspace?.v1PendingPersonalizationReviews ?? []
                state.v1Workspace = V1LearningWorkspaceFeature.State(
                    chapterID: chapterID, pageID: pageID,
                    v1PendingPersonalizationReviews: pending
                )
                state.route = .v1Learning(chapterID: chapterID)
                return .none

            case let .home(.delegate(.v1ChapterRequested(chapterID, pageID))):
                state.v1Workspace = V1LearningWorkspaceFeature.State(
                    chapterID: chapterID,
                    pageID: pageID,
                    v1PendingPersonalizationReviews: state.home
                        .v1PendingPersonalizationReviews
                )
                state.route = .v1Learning(chapterID: chapterID)
                return .none

            case .home(.delegate(.knowledgeSystemRequested)):
                state.knowledgeSystem = KnowledgeSystemFeature.State(
                    contentVersion: state.home.selectedContentVersion
                )
                state.route = .knowledgeSystem
                return .none

            case let .home(.delegate(.pageRequested(pageID))):
                state.learning = LearningFeature.State(pageID: pageID)
                state.route = .learning(pageID: pageID)
                return .none

            case .v1Workspace(.delegate(.homeRequested)):
                let pendingReviews = state.v1Workspace?
                    .v1PendingPersonalizationReviews ?? []
                state.route = .home
                return .send(.home(.v1WorkspaceReturned(pendingReviews)))

            case .learning(.delegate(.homeRequested)):
                state.route = .home
                state.learning = nil
                return .send(.home(.learningReturned))

            case .knowledgeSystem(.delegate(.homeRequested)):
                state.route = .home
                state.knowledgeSystem = nil
                return .none

            case let .knowledgeSystem(.delegate(.v1LearningRequested(
                chapterID,
                pageID
            ))):
                state.knowledgeSystem = nil
                state.v1Workspace = V1LearningWorkspaceFeature.State(
                    chapterID: chapterID,
                    pageID: pageID,
                    v1PendingPersonalizationReviews: state.home
                        .v1PendingPersonalizationReviews
                )
                state.route = .v1Learning(chapterID: chapterID)
                return .none

            case let .knowledgeSystem(.delegate(.learningRequested(pageID))):
                state.knowledgeSystem = nil
                state.learning = LearningFeature.State(pageID: pageID)
                state.route = .learning(pageID: pageID)
                return .none

            case .home, .v1Workspace, .learning, .knowledgeSystem:
                return .none
            }
        }
        .ifLet(\.v1Workspace, action: \.v1Workspace) {
            V1LearningWorkspaceFeature()
        }
        .ifLet(\.learning, action: \.learning) {
            LearningFeature()
        }
        .ifLet(\.knowledgeSystem, action: \.knowledgeSystem) {
            KnowledgeSystemFeature()
        }
    }
}
