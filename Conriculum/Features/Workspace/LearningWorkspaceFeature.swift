import ComposableArchitecture
import Foundation

@Reducer
struct LearningWorkspaceFeature {
    @ObservableState
    struct State: Equatable {
        var chapter: ChapterLearningFeature.State
        var knowledgeContext: KnowledgeContextFeature.State
        var sidebarMode: WorkspaceSidebarMode
        var isFocusModeEnabled: Bool
        var isInspectorPresented: Bool
        var wasInspectorPresentedBeforeFocus: Bool
        var pendingPersonalizationReviews: [
            KnowledgePersonalizationReview
        ] = []

        init(
            chapterID: ChapterID,
            pageID: LearningPageID,
            sidebarMode: WorkspaceSidebarMode = .automatic,
            isFocusModeEnabled: Bool = false,
            isInspectorPresented: Bool = false,
            pendingPersonalizationReviews: [
                KnowledgePersonalizationReview
            ] = []
        ) {
            chapter = ChapterLearningFeature.State(
                chapterID: chapterID,
                currentPageID: pageID
            )
            knowledgeContext = KnowledgeContextFeature.State(
                chapterID: chapterID,
                currentPageID: pageID,
                pendingPersonalizationReviews: pendingPersonalizationReviews
            )
            self.pendingPersonalizationReviews = pendingPersonalizationReviews
            self.sidebarMode = sidebarMode
            self.isFocusModeEnabled = isFocusModeEnabled
            self.isInspectorPresented = isInspectorPresented
            wasInspectorPresentedBeforeFocus = isInspectorPresented
        }
    }

    enum Action: Equatable {
        case chapter(ChapterLearningFeature.Action)
        case knowledgeContext(KnowledgeContextFeature.Action)
        case homeButtonTapped
        case sidebarVisibilityButtonTapped
        case sidebarModeChanged(WorkspaceSidebarMode)
        case focusModeButtonTapped
        case inspectorVisibilityButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case homeRequested
        case chapterRequested(ChapterID, LearningPageID)
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
            case let .chapter(.delegate(.chapterRequested(chapterID, pageID))):
                return .send(.delegate(.chapterRequested(chapterID, pageID)))

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
                state.knowledgeContext.pendingPersonalizationReviews = state
                    .pendingPersonalizationReviews
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
                state.knowledgeContext.pendingPersonalizationReviews = state
                    .pendingPersonalizationReviews
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
                    state.knowledgeContext.pendingPersonalizationReviews = state
                        .pendingPersonalizationReviews
                }
                return .send(.knowledgeContext(
                    .reloadRequested(.personalizationSaved)
                ))

            case .homeButtonTapped:
                return .send(.delegate(.homeRequested))

            case .sidebarVisibilityButtonTapped:
                if state.isFocusModeEnabled {
                    state.isFocusModeEnabled = false
                    state.sidebarMode = .visible
                    state.isInspectorPresented = false
                } else {
                    state.sidebarMode = state.sidebarMode == .hidden
                        ? .visible
                        : .hidden
                }
                return .none

            case let .sidebarModeChanged(mode):
                guard !state.isFocusModeEnabled else {
                    return .none
                }
                state.sidebarMode = mode
                return .none

            case .focusModeButtonTapped:
                if state.isFocusModeEnabled {
                    state.isFocusModeEnabled = false
                    state.isInspectorPresented =
                        state.wasInspectorPresentedBeforeFocus
                        && state.knowledgeContext.inspector != nil
                } else {
                    state.wasInspectorPresentedBeforeFocus =
                        state.isInspectorPresented
                    state.isInspectorPresented = false
                    state.isFocusModeEnabled = true
                }
                return .none

            case .inspectorVisibilityButtonTapped:
                guard state.knowledgeContext.inspector != nil else {
                    return .none
                }
                if state.isFocusModeEnabled {
                    state.isFocusModeEnabled = false
                    state.isInspectorPresented = true
                } else {
                    state.isInspectorPresented.toggle()
                }
                return .none

            case .knowledgeContext(.conceptSelected),
                 .knowledgeContext(.personalizationReviewRequested),
                 .knowledgeContext(.relationDraftRequested):
                guard state.knowledgeContext.inspector != nil else {
                    return .none
                }
                state.isFocusModeEnabled = false
                state.isInspectorPresented = true
                return .none

            case .knowledgeContext(.pageChanged),
                 .knowledgeContext(.inspectorDismissed),
                 .knowledgeContext(.personalizationReviewCancelled),
                 .knowledgeContext(.inspector(.delegate(.cancelled))),
                 .knowledgeContext(.inspector(.delegate(.saved))),
                 .knowledgeContext(.inspector(.delegate(.relationSaved))):
                guard state.knowledgeContext.inspector == nil else {
                    return .none
                }
                state.isInspectorPresented = false
                state.wasInspectorPresentedBeforeFocus = false
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
