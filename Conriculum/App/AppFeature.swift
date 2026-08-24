import ComposableArchitecture

@Reducer
struct AppFeature {
    static let chapter02ID = "chapter-02"

    @ObservableState
    struct State: Equatable {
        var route: Route = .home
    }

    enum Route: Equatable {
        case home
        case learningWorkspace(chapterID: String)
    }

    enum Action: Equatable {
        case chapterRequested(id: String)
        case homeRequested
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .chapterRequested(id):
                guard id == Self.chapter02ID else { return .none }
                state.route = .learningWorkspace(chapterID: id)
                return .none

            case .homeRequested:
                state.route = .home
                return .none
            }
        }
    }
}
