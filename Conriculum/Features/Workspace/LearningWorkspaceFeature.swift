import ComposableArchitecture
import Foundation

@Reducer
struct LearningWorkspaceFeature {
    @ObservableState
    struct State: Equatable {
        var chapter: ChapterLearningFeature.State
        var knowledgeContext: KnowledgeContextFeature.State
        var sidebarMode: WorkspaceSidebarMode
        var modeBeforeFocus: WorkspaceSidebarMode
        var pendingPersonalizationReviews: [
            KnowledgePersonalizationReview
        ] = []

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

    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid

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
                .promotionReviewRequested(
                    activityID,
                    targetConceptID,
                    expression
                )
            ))):
                guard let content = promotionContent(
                    activityID: activityID,
                    page: state.chapter.currentPage
                ),
                content.candidateKind == .conceptRevision,
                content.conceptIDs.contains(targetConceptID),
                let evidenceActivityID = content.evidenceActivityIDs.first
                else { return .none }

                let candidate = KnowledgePersonalizationCandidate(
                    id: KnowledgePersonalizationCandidateID(
                        rawValue: uuid().uuidString.lowercased()
                    ),
                    kind: content.candidateKind,
                    conceptIDs: content.conceptIDs,
                    draft: expression.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    evidenceActivityID: evidenceActivityID,
                    createdAt: now
                )
                let review = KnowledgePersonalizationReview(
                    candidate: candidate,
                    targetConceptID: targetConceptID,
                    activityID: activityID,
                    confirmationQuestion: content.confirmationQuestion,
                    savedFields: content.savedFields
                )
                state.pendingPersonalizationReviews.removeAll {
                    $0.activityID == activityID
                }
                state.pendingPersonalizationReviews.append(review)
                return .send(.knowledgeContext(
                    .personalizationReviewRequested(review)
                ))

            case let .chapter(.delegate(.personalKnowledge(
                .promotionCancelled(activityID)
            ))):
                let cancelledCandidateID = state
                    .pendingPersonalizationReviews
                    .first { $0.activityID == activityID }?
                    .id
                state.pendingPersonalizationReviews.removeAll {
                    $0.activityID == activityID
                }
                guard let cancelledCandidateID else { return .none }
                return .send(.knowledgeContext(
                    .personalizationReviewCancelled(cancelledCandidateID)
                ))

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

            case let .knowledgeContext(.delegate(.personalizationSaved(
                candidateID
            ))):
                if let candidateID {
                    state.pendingPersonalizationReviews.removeAll {
                        $0.id == candidateID
                    }
                }
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

    private func promotionContent(
        activityID: LearningActivityID,
        page: LearningPage?
    ) -> PersonalKnowledgePromotionContent? {
        guard let section = page?.sections.first(where: {
            $0.activityID == activityID
        }),
        case let .personalKnowledgePromotion(content) = section.content
        else { return nil }
        return content
    }
}
