import ComposableArchitecture

@Reducer
struct LearningWorkspaceFeature {
    @ObservableState
    struct State: Equatable {
        var chapter: ChapterLearningFeature.State
        var knowledgeContext: KnowledgeContextFeature.State

        init(
            chapterID: ChapterID,
            pageID: LearningPageID
        ) {
            chapter = ChapterLearningFeature.State(
                chapterID: chapterID,
                currentPageID: pageID
            )
            knowledgeContext = KnowledgeContextFeature.State(
                currentPageID: pageID
            )
        }
    }

    enum Action: Equatable {
        case chapter(ChapterLearningFeature.Action)
        case knowledgeContext(KnowledgeContextFeature.Action)
        case homeButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case homeRequested
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.chapter, action: \.chapter) {
            ChapterLearningFeature()
        }

        Scope(state: \.knowledgeContext, action: \.knowledgeContext) {
            KnowledgeContextFeature()
        }

        Reduce { _, action in
            switch action {
            case let .chapter(.delegate(.currentPageChanged(pageID))):
                return .send(.knowledgeContext(.pageChanged(pageID)))

            case .knowledgeContext(.delegate(.personalizationSaved)):
                return .send(.knowledgeContext(
                    .reloadRequested(.personalizationSaved)
                ))

            case .homeButtonTapped:
                return .send(.delegate(.homeRequested))

            case .chapter, .knowledgeContext, .delegate:
                return .none
            }
        }
    }
}
