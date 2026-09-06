import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var route: Route = .home
        var home = HomeFeature.State()
        var workspace: LearningWorkspaceFeature.State?
        var v2Learning: V2LearningFeature.State?
        var knowledgeSystem: KnowledgeSystemFeature.State?
    }

    enum Route: Equatable {
        case home
        case learningWorkspace(chapterID: ChapterID)
        case v2Learning(pageID: String)
        case knowledgeSystem
    }

    enum Action: Equatable {
        case home(HomeFeature.Action)
        case workspace(LearningWorkspaceFeature.Action)
        case v2Learning(V2LearningFeature.Action)
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
                state.knowledgeSystem = KnowledgeSystemFeature.State(
                    contentVersion: state.home.selectedContentVersion
                )
                state.route = .knowledgeSystem
                return .none

            case let .home(.delegate(.v2PageRequested(pageID))):
                state.v2Learning = V2LearningFeature.State(pageID: pageID)
                state.route = .v2Learning(pageID: pageID)
                return .none

            case .workspace(.delegate(.homeRequested)):
                let pendingReviews = state.workspace?
                    .pendingPersonalizationReviews ?? []
                state.route = .home
                return .send(.home(.workspaceReturned(pendingReviews)))

            case .v2Learning(.delegate(.homeRequested)):
                state.route = .home
                state.v2Learning = nil
                return .send(.home(.v2WorkspaceReturned))

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

            case let .knowledgeSystem(.delegate(.v2LearningRequested(pageID))):
                state.knowledgeSystem = nil
                state.v2Learning = V2LearningFeature.State(pageID: pageID)
                state.route = .v2Learning(pageID: pageID)
                return .none

            case .home, .workspace, .v2Learning, .knowledgeSystem:
                return .none
            }
        }
        .ifLet(\.workspace, action: \.workspace) {
            LearningWorkspaceFeature()
        }
        .ifLet(\.v2Learning, action: \.v2Learning) {
            V2LearningFeature()
        }
        .ifLet(\.knowledgeSystem, action: \.knowledgeSystem) {
            KnowledgeSystemFeature()
        }
    }
}
