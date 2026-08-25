import ComposableArchitecture

@Reducer
struct ChapterLearningFeature {
    @ObservableState
    struct State: Equatable {
        let chapterID: ChapterID
        var currentPageID: LearningPageID
    }

    enum Action: Equatable {
        case currentPageChanged(LearningPageID)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case currentPageChanged(LearningPageID)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .currentPageChanged(pageID):
                guard state.currentPageID != pageID else { return .none }
                state.currentPageID = pageID
                return .send(.delegate(.currentPageChanged(pageID)))

            case .delegate:
                return .none
            }
        }
    }
}
