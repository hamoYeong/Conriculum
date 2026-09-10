import ComposableArchitecture

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var route: Route = .home
        var home = HomeFeature.State()
        var learning: LearningFeature.State?
        var knowledgeSystem: KnowledgeSystemFeature.State?
    }

    enum Route: Equatable {
        case home
        case learning(pageID: String)
        case knowledgeSystem
    }

    enum Action: Equatable {
        case home(HomeFeature.Action)
        case learning(LearningFeature.Action)
        case knowledgeSystem(KnowledgeSystemFeature.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }

        Reduce { state, action in
            switch action {
            case .home(.delegate(.knowledgeSystemRequested)):
                state.knowledgeSystem = KnowledgeSystemFeature.State()
                state.route = .knowledgeSystem
                return .none

            case let .home(.delegate(.pageRequested(pageID))):
                state.learning = LearningFeature.State(pageID: pageID)
                state.route = .learning(pageID: pageID)
                return .none

            case .learning(.delegate(.homeRequested)):
                state.route = .home
                state.learning = nil
                return .send(.home(.learningReturned))

            case .knowledgeSystem(.delegate(.homeRequested)):
                state.route = .home
                state.knowledgeSystem = nil
                return .none

            case let .knowledgeSystem(.delegate(.learningRequested(pageID))):
                state.knowledgeSystem = nil
                state.learning = LearningFeature.State(pageID: pageID)
                state.route = .learning(pageID: pageID)
                return .none

            case .home, .learning, .knowledgeSystem:
                return .none
            }
        }
        .ifLet(\.learning, action: \.learning) {
            LearningFeature()
        }
        .ifLet(\.knowledgeSystem, action: \.knowledgeSystem) {
            KnowledgeSystemFeature()
        }
    }
}
