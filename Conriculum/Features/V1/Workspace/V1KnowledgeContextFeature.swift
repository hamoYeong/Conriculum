import ComposableArchitecture
import Foundation

@Reducer
struct V1KnowledgeContextFeature {
    enum ReloadReason: Equatable, Sendable {
        case initial
        case pageChanged
        case personalizationSaved
    }

    @ObservableState
    struct State: Equatable {
        let chapterID: ChapterID
        var currentPageID: LearningPageID
        var snapshot: V1KnowledgeContextSnapshot?
        var isLoading = false
        var loadErrorMessage: String?
        var lastReloadReason: ReloadReason?
        var reloadRequestCount = 0
        var inspector: V1ConceptInspectorFeature.State?
        var v1PendingPersonalizationReviews: [
            V1KnowledgePersonalizationReview
        ]

        init(
            chapterID: ChapterID,
            currentPageID: LearningPageID,
            snapshot: V1KnowledgeContextSnapshot? = nil,
            v1PendingPersonalizationReviews: [
                V1KnowledgePersonalizationReview
            ] = []
        ) {
            self.chapterID = chapterID
            self.currentPageID = currentPageID
            self.snapshot = snapshot
            self.v1PendingPersonalizationReviews = v1PendingPersonalizationReviews
        }
    }

    enum Action: Equatable {
        case task
        case pageChanged(LearningPageID)
        case conceptSelected(KnowledgeConceptID)
        case personalizationReviewRequested(V1KnowledgePersonalizationReview)
        case personalizationReviewCancelled(
            KnowledgePersonalizationCandidateID
        )
        case relationDraftRequested(V1PersonalRelationDraftRequest)
        case inspectorDismissed
        case inspector(V1ConceptInspectorFeature.Action)
        case personalizationSaved(
            candidateID: KnowledgePersonalizationCandidateID?
        )
        case reloadRequested(ReloadReason)
        case loadResponse(LoadResponse)
        case delegate(Delegate)
    }

    enum LoadResponse: Equatable, Sendable {
        case loaded(V1KnowledgeContextSnapshot)
        case failed(pageID: LearningPageID, message: String)
    }

    enum Delegate: Equatable {
        case personalizationSaved(
            candidateID: KnowledgePersonalizationCandidateID?
        )
        case learningRequested(ChapterID, LearningPageID)
    }

    @Dependency(\.v1CurriculumClient) var v1CurriculumClient
    @Dependency(\.v1KnowledgeCatalogClient) var v1KnowledgeCatalogClient
    @Dependency(\.v1PersonalKnowledgeClient) var v1PersonalKnowledgeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard state.snapshot == nil, !state.isLoading else {
                    return .none
                }
                return .send(.reloadRequested(.initial))

            case let .pageChanged(pageID):
                state.currentPageID = pageID
                state.snapshot = nil
                state.loadErrorMessage = nil
                state.inspector = nil
                return .send(.reloadRequested(.pageChanged))

            case let .conceptSelected(conceptID):
                guard let snapshot = state.snapshot,
                      let item = conceptItem(
                          id: conceptID,
                          in: snapshot
                      )
                else { return .none }
                state.inspector = V1ConceptInspectorFeature.State(
                    sourcePageTitle: snapshot.pageTitle,
                    item: item,
                    availableConcepts: snapshot.availableConcepts,
                    baseRelations: snapshot.baseRelations,
                    personalRelations: snapshot.personalRelations,
                    relationCreationContract: snapshot
                        .relationCreationContract
                )
                return .none

            case let .personalizationReviewRequested(review):
                guard review.candidate.kind == .conceptRevision,
                      review.candidate.conceptIDs.contains(
                          review.targetConceptID
                      )
                else { return .none }
                state.v1PendingPersonalizationReviews.removeAll {
                    $0.activityID == review.activityID
                }
                state.v1PendingPersonalizationReviews.append(review)
                guard let snapshot = state.snapshot,
                      let item = conceptItem(
                          id: review.targetConceptID,
                          in: snapshot
                      )
                else { return .none }
                state.inspector = V1ConceptInspectorFeature.State(
                    sourcePageTitle: snapshot.pageTitle,
                    item: item,
                    availableConcepts: snapshot.availableConcepts,
                    baseRelations: snapshot.baseRelations,
                    personalRelations: snapshot.personalRelations,
                    relationCreationContract: snapshot
                        .relationCreationContract,
                    personalizationReview: review
                )
                return .none

            case let .personalizationReviewCancelled(candidateID):
                state.v1PendingPersonalizationReviews.removeAll {
                    $0.id == candidateID
                }
                guard state.inspector?.personalizationReview?.id
                    == candidateID
                else { return .none }
                state.inspector = nil
                return .none

            case let .relationDraftRequested(request):
                guard let snapshot = state.snapshot,
                      let contract = snapshot.relationCreationContract,
                      contract.sourceConceptIDs.contains(
                          request.sourceConceptID
                      ),
                      contract.targetConceptIDs.contains(
                          request.targetConceptID
                      ),
                      request.sourceConceptID != request.targetConceptID,
                      let item = conceptItem(
                          id: request.sourceConceptID,
                          in: snapshot
                      )
                else { return .none }
                var inspector = V1ConceptInspectorFeature.State(
                    sourcePageTitle: snapshot.pageTitle,
                    item: item,
                    availableConcepts: snapshot.availableConcepts,
                    baseRelations: snapshot.baseRelations,
                    personalRelations: snapshot.personalRelations,
                    relationCreationContract: contract
                )
                inspector.relationEditor = V1PersonalRelationEditorFeature.State(
                    request: request,
                    contract: contract,
                    availableConcepts: snapshot.availableConcepts
                )
                state.inspector = inspector
                return .none

            case .inspectorDismissed,
                 .inspector(.delegate(.cancelled)):
                state.inspector = nil
                return .none

            case .inspector(.delegate(.saved)):
                let candidateID = state.inspector?.personalizationReview?.id
                if let candidateID {
                    state.v1PendingPersonalizationReviews.removeAll {
                        $0.id == candidateID
                    }
                }
                state.inspector = nil
                return .send(.personalizationSaved(
                    candidateID: candidateID
                ))

            case .inspector(.delegate(.relationSaved)):
                state.inspector = nil
                return .send(.personalizationSaved(candidateID: nil))

            case let .inspector(.delegate(.learningRequested(
                chapterID,
                pageID
            ))):
                state.inspector = nil
                return .send(.delegate(.learningRequested(chapterID, pageID)))

            case let .personalizationSaved(candidateID):
                return .send(.delegate(.personalizationSaved(
                    candidateID: candidateID
                )))

            case let .reloadRequested(reason):
                state.lastReloadReason = reason
                state.reloadRequestCount += 1
                state.isLoading = true
                state.loadErrorMessage = nil
                let chapterID = state.chapterID
                let pageID = state.currentPageID

                return .run { send in
                    do {
                        async let chapter = v1CurriculumClient.loadChapter(
                            chapterID
                        )
                        async let catalog = v1KnowledgeCatalogClient.loadCatalog()
                        let loadedChapter = try await chapter
                        let loadedCatalog = try await catalog
                        let conceptIDs = await MainActor.run {
                            V1KnowledgeContextSnapshotComposer
                                .chapterConceptIDs(in: loadedChapter)
                        }
                        var revisions: [PersonalConceptRevision] = []
                        var relations: [PersonalKnowledgeRelation] = []
                        for conceptID in conceptIDs {
                            async let conceptRevisions =
                                v1PersonalKnowledgeClient.loadRevisions(conceptID)
                            async let conceptRelations =
                                v1PersonalKnowledgeClient.loadRelations(conceptID)
                            revisions += try await conceptRevisions
                            relations += try await conceptRelations
                        }
                        let loadedRevisions = revisions
                        let loadedRelations = relations
                        let snapshot = try await MainActor.run {
                            try V1KnowledgeContextSnapshotComposer().compose(
                                chapter: loadedChapter,
                                catalog: loadedCatalog,
                                pageID: pageID,
                                revisions: loadedRevisions,
                                relations: loadedRelations
                            )
                        }
                        await send(.loadResponse(.loaded(snapshot)))
                    } catch {
                        await send(.loadResponse(.failed(
                            pageID: pageID,
                            message: error.localizedDescription
                        )))
                    }
                }
                .cancellable(
                    id: "V1KnowledgeContextFeature.load",
                    cancelInFlight: true
                )

            case let .loadResponse(.loaded(snapshot)):
                guard snapshot.pageID == state.currentPageID else {
                    return .none
                }
                state.snapshot = snapshot
                state.isLoading = false
                state.loadErrorMessage = nil
                return .none

            case let .loadResponse(.failed(pageID, message)):
                guard pageID == state.currentPageID else { return .none }
                state.isLoading = false
                state.loadErrorMessage = message
                return .none

            case .inspector, .delegate:
                return .none
            }
        }
        .ifLet(\.inspector, action: \.inspector) {
            V1ConceptInspectorFeature()
        }
    }

    private func conceptItem(
        id: KnowledgeConceptID,
        in snapshot: V1KnowledgeContextSnapshot
    ) -> V1KnowledgeContextSnapshot.ConceptItem? {
        (snapshot.directConcepts
            + snapshot.changedConcepts
            + snapshot.nearbyConcepts)
            .first { $0.id == id }
    }
}
