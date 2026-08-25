import ComposableArchitecture

@Reducer
struct LearningWorkspaceFeature {
    @ObservableState
    struct State: Equatable {
        var chapter: ChapterLearningFeature.State
        var knowledgeContext: KnowledgeContextFeature.State
        var sidebarMode: WorkspaceSidebarMode
        var modeBeforeFocus: WorkspaceSidebarMode

        init(
            chapterID: ChapterID,
            pageID: LearningPageID,
            sidebarMode: WorkspaceSidebarMode = .automatic
        ) {
            chapter = ChapterLearningFeature.State(
                chapterID: chapterID,
                currentPageID: pageID
            )
            knowledgeContext = KnowledgeContextFeature.State(
                chapterID: chapterID,
                currentPageID: pageID
            )
            self.sidebarMode = sidebarMode
            modeBeforeFocus = sidebarMode == .focus
                ? .automatic
                : sidebarMode
        }
    }

    enum Action: Equatable {
        case chapter(ChapterLearningFeature.Action)
        case knowledgeContext(KnowledgeContextFeature.Action)
        case homeButtonTapped
        case sidebarModeChanged(WorkspaceSidebarMode)
        case focusModeButtonTapped
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

        Reduce { state, action in
            switch action {
            case let .chapter(.delegate(.currentPageChanged(pageID))):
                return .send(.knowledgeContext(.pageChanged(pageID)))

            case let .chapter(.delegate(.personalKnowledge(
                .relationConfirmed(
                    _,
                    sourceConceptID,
                    targetConceptID,
                    statement,
                    reason,
                    evidenceActivityID
                )
            ))):
                return .send(.knowledgeContext(.relationDraftRequested(
                    PersonalRelationDraftRequest(
                        sourceConceptID: sourceConceptID,
                        targetConceptID: targetConceptID,
                        statement: statement,
                        reason: reason,
                        evidenceActivityID: evidenceActivityID
                    )
                )))

            case .knowledgeContext(.delegate(.personalizationSaved)):
                return .send(.knowledgeContext(
                    .reloadRequested(.personalizationSaved)
                ))

            case .homeButtonTapped:
                return .send(.delegate(.homeRequested))

            case let .sidebarModeChanged(mode):
                if mode != .focus {
                    state.modeBeforeFocus = mode
                }
                state.sidebarMode = mode
                return .none

            case .focusModeButtonTapped:
                if state.sidebarMode == .focus {
                    state.sidebarMode = state.modeBeforeFocus
                } else {
                    state.modeBeforeFocus = state.sidebarMode
                    state.sidebarMode = .focus
                }
                return .none

            case .chapter, .knowledgeContext, .delegate:
                return .none
            }
        }
    }
}
