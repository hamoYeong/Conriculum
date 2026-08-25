import ComposableArchitecture

@Reducer
struct KnowledgeContextFeature {
    enum ReloadReason: Equatable, Sendable {
        case pageChanged
        case personalizationSaved
    }

    @ObservableState
    struct State: Equatable {
        var currentPageID: LearningPageID
        var lastReloadReason: ReloadReason?
        var reloadRequestCount = 0
    }

    enum Action: Equatable {
        case pageChanged(LearningPageID)
        case personalizationSaved
        case reloadRequested(ReloadReason)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case personalizationSaved
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .pageChanged(pageID):
                state.currentPageID = pageID
                return .send(.reloadRequested(.pageChanged))

            case .personalizationSaved:
                return .send(.delegate(.personalizationSaved))

            case let .reloadRequested(reason):
                state.lastReloadReason = reason
                state.reloadRequestCount += 1
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
