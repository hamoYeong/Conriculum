import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct LearningWorkspaceFeatureTests {
    @Test
    func savedPageNavigationRefreshesTheKnowledgeContext() async throws {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageOne = try #require(chapter.progressPageIDs.first)
        let pageTwo = try #require(chapter.progressPageIDs.dropFirst().first)
        let expectedSnapshot = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageTwo,
            revisions: []
        )
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let progress = LearningProgress(
            chapterID: chapter.id,
            currentPageID: pageTwo,
            completedPageIDs: [],
            updatedAt: timestamp
        )
        var initialState = LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageOne
        )
        initialState.chapter.chapter = chapter
        let store = TestStore(
            initialState: initialState
        ) {
            LearningWorkspaceFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.learningRecordClient.saveProgress = { _ in }
            $0.curriculumClient.loadChapter = { _ in chapter }
            $0.knowledgeCatalogClient.loadCatalog = { catalog }
            $0.personalKnowledgeClient.loadRevisions = { _ in [] }
            $0.personalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.chapter(.nextButtonTapped)) {
            $0.chapter.isSavingNavigation = true
        }
        await store.receive(.chapter(.navigationResponse(.saved(
            destination: .page(pageTwo),
            progress: progress,
            drafts: []
        )))) {
            $0.chapter.isSavingNavigation = false
            $0.chapter.currentPageID = pageTwo
        }
        await store.receive(.chapter(.delegate(.currentPageChanged(pageTwo))))
        await store.receive(.knowledgeContext(.pageChanged(pageTwo))) {
            $0.knowledgeContext.currentPageID = pageTwo
        }
        await store.receive(
            .knowledgeContext(.reloadRequested(.pageChanged))
        ) {
            $0.knowledgeContext.isLoading = true
            $0.knowledgeContext.lastReloadReason = .pageChanged
            $0.knowledgeContext.reloadRequestCount = 1
        }
        await store.receive(
            .knowledgeContext(.loadResponse(.loaded(expectedSnapshot)))
        ) {
            $0.knowledgeContext.snapshot = expectedSnapshot
            $0.knowledgeContext.isLoading = false
        }
    }

    @Test
    func failedSaveKeepsTheCurrentPageAndDraft() async throws {
        let chapter = try loadChapter()
        let pageOne = try #require(chapter.progressPageIDs.first)
        let page = try #require(chapter.page(id: pageOne))
        let activityID = try #require(page.activities.first?.id)
        let fields = [
            ActivityResponseField(
                key: "reason",
                values: ["저장 실패 뒤에도 남아야 하는 초안"]
            )
        ]
        let responseUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000002"
        )!
        let draft = ChapterLearningFeature.ActivityDraft(
            responseID: ActivityResponseID(
                rawValue: responseUUID.uuidString.lowercased()
            ),
            activityID: activityID,
            fields: fields
        )
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let clock = TestClock()
        var initialState = LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageOne
        )
        initialState.chapter.chapter = chapter
        let store = TestStore(initialState: initialState) {
            LearningWorkspaceFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.uuid = .constant(responseUUID)
            $0.continuousClock = clock
            $0.learningRecordClient.saveResponse = { _ in }
            $0.learningRecordClient.saveProgress = { _ in
                throw NSError(
                    domain: "LearningWorkspaceFeatureTests",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "테스트 저장 실패"
                    ]
                )
            }
        }

        await store.send(.chapter(.activityDraftChanged(
            activityID: activityID,
            fields: fields
        ))) {
            $0.chapter.activityDrafts[activityID] = draft
            $0.chapter.activitySaveStates[activityID] = .pending
        }
        await store.send(.chapter(.nextButtonTapped)) {
            $0.chapter.isSavingNavigation = true
            $0.chapter.activitySaveStates[activityID] = .saving
        }
        await store.receive(.chapter(.navigationResponse(.failed(
            drafts: [draft],
            savedActivityIDs: [activityID],
            savedAt: timestamp,
            message: "테스트 저장 실패"
        )))) {
            $0.chapter.isSavingNavigation = false
            $0.chapter.navigationErrorMessage = "테스트 저장 실패"
            $0.chapter.activitySaveStates[activityID] = .saved(timestamp)
        }

        #expect(store.state.chapter.currentPageID == pageOne)
        #expect(store.state.chapter.activityDrafts[activityID] == draft)
        #expect(store.state.knowledgeContext.reloadRequestCount == 0)
    }

    @Test
    func lastPageShowsCompletionSummaryWithoutChangingItsIdentity() async throws {
        let chapter = try loadChapter()
        let lastPageID = try #require(chapter.progressPageIDs.last)
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let progress = LearningProgress(
            chapterID: chapter.id,
            currentPageID: lastPageID,
            completedPageIDs: [],
            updatedAt: timestamp
        )
        let pendingReview = KnowledgePersonalizationReview(
            candidate: KnowledgePersonalizationCandidate(
                id: "candidate-page08-pending",
                kind: .conceptRevision,
                conceptIDs: ["concept-value", "concept-type-selection"],
                draft: "값의 의미와 할 일을 보고 타입을 선택한다.",
                evidenceActivityID: "activity-page08-free-response",
                createdAt: timestamp
            ),
            targetConceptID: "concept-type-selection",
            activityID: "activity-page08-promotion",
            confirmationQuestion: "이 문장을 나의 현재 언어로 반영할까?",
            savedFields: ["나의 설명", "근거 활동 ID"]
        )
        var initialState = LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: lastPageID,
            pendingPersonalizationReviews: [pendingReview]
        )
        initialState.chapter.chapter = chapter
        let store = TestStore(initialState: initialState) {
            LearningWorkspaceFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.learningRecordClient.saveProgress = { _ in }
        }

        await store.send(.chapter(.nextButtonTapped)) {
            $0.chapter.isSavingNavigation = true
        }
        await store.receive(.chapter(.navigationResponse(.saved(
            destination: .completionSummary,
            progress: progress,
            drafts: []
        )))) {
            $0.chapter.isSavingNavigation = false
            $0.chapter.isShowingCompletionSummary = true
        }

        #expect(store.state.chapter.currentPageID == lastPageID)
        #expect(store.state.chapter.completedPageIDs.isEmpty)
        #expect(store.state.pendingPersonalizationReviews == [pendingReview])
        #expect(store.state.knowledgeContext.reloadRequestCount == 0)
    }

    @Test
    func personalizationResultRefreshesOnlyTheKnowledgeChild() async throws {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageID: LearningPageID = "chapter-02-page-03"
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let revision = PersonalConceptRevision(
            id: "revision-sidebar-refresh",
            conceptID: "concept-type-selection",
            personalTitle: "할 일을 먼저 보는 타입 선택",
            explanation: "값의 의미와 이후 할 일을 기준으로 타입을 고른다.",
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: "activity-page03-choice",
            createdAt: timestamp
        )
        let relation = PersonalKnowledgeRelation(
            id: "relation-sidebar-refresh",
            sourceConceptID: "concept-value",
            targetConceptID: "concept-type-selection",
            statement: "값의 의미는 타입 선택의 기준으로 이어진다.",
            reason: "이후 가능한 사용을 함께 판단하기 때문이다.",
            evidenceActivityID: "activity-page03-choice",
            createdAt: timestamp.addingTimeInterval(60)
        )
        let pendingReview = KnowledgePersonalizationReview(
            candidate: KnowledgePersonalizationCandidate(
                id: "candidate-sidebar-refresh",
                kind: .conceptRevision,
                conceptIDs: ["concept-value", "concept-type-selection"],
                draft: revision.explanation,
                evidenceActivityID: revision.evidenceActivityID,
                createdAt: timestamp
            ),
            targetConceptID: revision.conceptID,
            activityID: "activity-page03-promotion",
            confirmationQuestion: "이 설명을 나의 지식으로 반영할까?",
            savedFields: ["나의 설명", "근거 활동 ID"]
        )
        let expectedSnapshot = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: [revision],
            relations: [relation]
        )
        let store = TestStore(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: pageID,
                pendingPersonalizationReviews: [pendingReview]
            )
        ) {
            LearningWorkspaceFeature()
        } withDependencies: {
            $0.curriculumClient.loadChapter = { _ in chapter }
            $0.knowledgeCatalogClient.loadCatalog = { catalog }
            $0.personalKnowledgeClient.loadRevisions = { conceptID in
                conceptID == revision.conceptID ? [revision] : []
            }
            $0.personalKnowledgeClient.loadRelations = { conceptID in
                conceptID == relation.sourceConceptID
                    || conceptID == relation.targetConceptID
                    ? [relation]
                    : []
            }
        }

        await store.send(.knowledgeContext(.personalizationSaved(
            candidateID: pendingReview.id
        )))
        await store.receive(
            .knowledgeContext(.delegate(.personalizationSaved(
                candidateID: pendingReview.id
            )))
        ) {
            $0.pendingPersonalizationReviews = []
            $0.knowledgeContext.pendingPersonalizationReviews = []
        }
        await store.receive(
            .knowledgeContext(.reloadRequested(.personalizationSaved))
        ) {
            $0.knowledgeContext.isLoading = true
            $0.knowledgeContext.lastReloadReason = .personalizationSaved
            $0.knowledgeContext.reloadRequestCount = 1
        }
        await store.receive(
            .knowledgeContext(.loadResponse(.loaded(expectedSnapshot)))
        ) {
            $0.knowledgeContext.snapshot = expectedSnapshot
            $0.knowledgeContext.isLoading = false
        }
    }

    @Test
    func failedCandidateSaveKeepsTheReviewPendingWithoutRefreshing()
        async throws
    {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageID: LearningPageID = "chapter-02-page-05"
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let snapshot = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: []
        )
        let review = KnowledgePersonalizationReview(
            candidate: KnowledgePersonalizationCandidate(
                id: "candidate-save-failure",
                kind: .conceptRevision,
                conceptIDs: [
                    "concept-constants-variables",
                    "concept-problem-boundary",
                ],
                draft: "변경 가능성은 현재 책임의 범위로 판단한다.",
                evidenceActivityID: "activity-page05-card-sorting",
                createdAt: timestamp
            ),
            targetConceptID: "concept-constants-variables",
            activityID: "activity-page05-promotion",
            confirmationQuestion: "이 설명을 나의 지식으로 반영할까?",
            savedFields: ["나의 설명", "근거 활동 ID"]
        )
        let item = try #require(snapshot.directConcepts.first {
            $0.id == review.targetConceptID
        })
        var initialState = LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageID,
            pendingPersonalizationReviews: [review]
        )
        initialState.chapter.chapter = chapter
        initialState.chapter.knowledgeCatalog = catalog
        initialState.knowledgeContext.snapshot = snapshot
        initialState.knowledgeContext.inspector = ConceptInspectorFeature.State(
            sourcePageTitle: snapshot.pageTitle,
            item: item,
            availableConcepts: snapshot.availableConcepts,
            baseRelations: snapshot.baseRelations,
            personalRelations: snapshot.personalRelations,
            relationCreationContract: snapshot.relationCreationContract,
            personalizationReview: review
        )
        let store = TestStore(initialState: initialState) {
            LearningWorkspaceFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.uuid = .constant(UUID(
                uuidString: "00000000-0000-0000-0000-000000000085"
            )!)
            $0.personalKnowledgeClient.saveRevision = { _ in
                throw NSError(
                    domain: "LearningWorkspaceFeatureTests",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "테스트 후보 저장 실패"
                    ]
                )
            }
        }

        await store.send(.knowledgeContext(.inspector(
            .saveButtonTapped
        ))) {
            $0.knowledgeContext.inspector?.isSaving = true
        }
        await store.receive(.knowledgeContext(.inspector(
            .saveResponse(.failed("테스트 후보 저장 실패"))
        ))) {
            $0.knowledgeContext.inspector?.isSaving = false
            $0.knowledgeContext.inspector?.persistenceErrorMessage =
                "테스트 후보 저장 실패"
        }

        #expect(store.state.pendingPersonalizationReviews == [review])
        #expect(
            store.state.knowledgeContext.pendingPersonalizationReviews
                == [review]
        )
        #expect(
            store.state.knowledgeContext.inspector?.personalizationReview
                == review
        )
        #expect(store.state.knowledgeContext.reloadRequestCount == 0)
    }

    @Test
    func pageRelationConfirmationRoutesItsDraftToTheKnowledgeInspector()
        async throws
    {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageID: LearningPageID = "chapter-02-page-07"
        let snapshot = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: []
        )
        let request = PersonalRelationDraftRequest(
            sourceConceptID: "concept-related-value-grouping",
            targetConceptID: "concept-type-modeling",
            statement: "값 묶기의 경계는 타입 책임으로 이어진다.",
            reason: "관련 값을 구조로 보존하기 때문이다.",
            evidenceActivityID: "activity-page07-role-sorting"
        )
        let componentAction = PersonalKnowledgeComponentAction
            .relationConfirmed(
                activityID: "activity-page07-relation",
                sourceConceptID: request.sourceConceptID,
                targetConceptID: request.targetConceptID,
                statement: request.statement,
                reason: request.reason,
                evidenceActivityID: request.evidenceActivityID
            )
        let item = try #require(snapshot.directConcepts.first {
            $0.id == request.sourceConceptID
        })
        let contract = try #require(snapshot.relationCreationContract)
        var expectedInspector = ConceptInspectorFeature.State(
            sourcePageTitle: snapshot.pageTitle,
            item: item,
            availableConcepts: snapshot.availableConcepts,
            baseRelations: snapshot.baseRelations,
            personalRelations: snapshot.personalRelations,
            relationCreationContract: contract
        )
        expectedInspector.relationEditor = PersonalRelationEditorFeature.State(
            request: request,
            contract: contract,
            availableConcepts: snapshot.availableConcepts
        )
        var initialState = LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageID
        )
        initialState.chapter.chapter = chapter
        initialState.chapter.knowledgeCatalog = catalog
        initialState.knowledgeContext.snapshot = snapshot
        let store = TestStore(initialState: initialState) {
            LearningWorkspaceFeature()
        }

        await store.send(.chapter(.delegate(.personalKnowledge(
            componentAction
        ))))
        await store.receive(.knowledgeContext(.relationDraftRequested(
            request
        ))) {
            $0.knowledgeContext.inspector = expectedInspector
        }
    }

    @Test
    func activityPromotionCreatesAReviewWithoutSavingAndDismissKeepsTheDraft()
        async throws
    {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageID: LearningPageID = "chapter-02-page-05"
        let activityID: LearningActivityID = "activity-page05-promotion"
        let targetConceptID: KnowledgeConceptID =
            "concept-constants-variables"
        let expression = "변경 가능성은 현재 책임의 범위로 판단한다."
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let candidateUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000084"
        )!
        let snapshot = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: []
        )
        let responseDraft = ChapterLearningFeature.ActivityDraft(
            responseID: "response-page05-promotion",
            activityID: activityID,
            fields: [
                ActivityResponseField(
                    key: LearningActivityFieldKey.personalExpression,
                    values: [expression]
                ),
                ActivityResponseField(
                    key: LearningActivityFieldKey
                        .personalizationTargetConceptID,
                    values: [targetConceptID.rawValue]
                ),
            ]
        )
        let candidate = KnowledgePersonalizationCandidate(
            id: KnowledgePersonalizationCandidateID(
                rawValue: candidateUUID.uuidString.lowercased()
            ),
            kind: .conceptRevision,
            conceptIDs: [
                "concept-constants-variables",
                "concept-problem-boundary",
            ],
            draft: expression,
            evidenceActivityID: "activity-page05-card-sorting",
            createdAt: timestamp
        )
        let review = KnowledgePersonalizationReview(
            candidate: candidate,
            targetConceptID: targetConceptID,
            activityID: activityID,
            confirmationQuestion:
                "이 문장과 범위가 다른 예를 나의 변경 책임 기준으로 남길까?",
            savedFields: [
                "나의 설명",
                "let 예시",
                "var 예시",
                "판단 경계",
                "근거 활동 ID",
                "수정 시각",
            ]
        )
        let item = try #require(snapshot.directConcepts.first {
            $0.id == targetConceptID
        })
        let expectedInspector = ConceptInspectorFeature.State(
            sourcePageTitle: snapshot.pageTitle,
            item: item,
            availableConcepts: snapshot.availableConcepts,
            baseRelations: snapshot.baseRelations,
            personalRelations: snapshot.personalRelations,
            relationCreationContract: snapshot.relationCreationContract,
            personalizationReview: review
        )
        let saveSpy = PersonalizationSaveSpy()
        var initialState = LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageID
        )
        initialState.chapter.chapter = chapter
        initialState.chapter.knowledgeCatalog = catalog
        initialState.chapter.activityDrafts[activityID] = responseDraft
        initialState.chapter.activitySaveStates[activityID] = .saved(timestamp)
        initialState.knowledgeContext.snapshot = snapshot
        let store = TestStore(initialState: initialState) {
            LearningWorkspaceFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.uuid = .constant(candidateUUID)
            $0.personalKnowledgeClient.saveRevision = { revision in
                await saveSpy.save(revision)
            }
        }
        let componentAction = PersonalKnowledgeComponentAction
            .promotionReviewRequested(
                activityID: activityID,
                targetConceptID: targetConceptID,
                expression: "  \(expression)  "
            )

        await store.send(.chapter(.delegate(.personalKnowledge(
            componentAction
        )))) {
            $0.pendingPersonalizationReviews = [review]
            $0.knowledgeContext.pendingPersonalizationReviews = [review]
        }
        await store.receive(.knowledgeContext(
            .personalizationReviewRequested(review)
        )) {
            $0.knowledgeContext.inspector = expectedInspector
        }

        let savesBeforeConfirmation = await saveSpy.savedRevisions()
        #expect(savesBeforeConfirmation.isEmpty)

        await store.send(.knowledgeContext(.inspector(
            .cancelButtonTapped
        )))
        await store.receive(.knowledgeContext(.inspector(
            .delegate(.cancelled)
        ))) {
            $0.knowledgeContext.inspector = nil
        }
        #expect(store.state.pendingPersonalizationReviews == [review])

        await store.send(.chapter(.delegate(.personalKnowledge(
            .promotionCancelled(activityID)
        )))) {
            $0.pendingPersonalizationReviews = []
            $0.knowledgeContext.pendingPersonalizationReviews = []
        }
        await store.receive(.knowledgeContext(
            .personalizationReviewCancelled(candidate.id)
        ))

        #expect(
            store.state.chapter.activityDrafts[activityID] == responseDraft
        )
        let savesAfterDismiss = await saveSpy.savedRevisions()
        #expect(savesAfterDismiss.isEmpty)
    }

    @Test
    func homeButtonDelegatesWithoutOwningAppRouting() async {
        let store = TestStore(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: "chapter-02-overview"
            )
        ) {
            LearningWorkspaceFeature()
        }

        await store.send(.homeButtonTapped)
        await store.receive(.delegate(.homeRequested))
    }

    @Test
    func focusModeReturnsToTheModeThatWasVisibleBeforeIt() async {
        let store = TestStore(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: "chapter-02-page-03"
            )
        ) {
            LearningWorkspaceFeature()
        }

        await store.send(.sidebarModeChanged(.visible)) {
            $0.sidebarMode = .visible
            $0.modeBeforeFocus = .visible
        }
        await store.send(.focusModeButtonTapped) {
            $0.sidebarMode = .focus
        }
        await store.send(.focusModeButtonTapped) {
            $0.sidebarMode = .visible
        }
        await store.send(.sidebarModeChanged(.automatic)) {
            $0.sidebarMode = .automatic
            $0.modeBeforeFocus = .automatic
        }
        await store.send(.focusModeButtonTapped) {
            $0.sidebarMode = .focus
        }
        await store.send(.focusModeButtonTapped) {
            $0.sidebarMode = .automatic
        }
    }

    @Test
    func automaticIsTheDefaultAndFocusDoesNotPersistAcrossNewState() async {
        let store = TestStore(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: "chapter-02-overview"
            )
        ) {
            LearningWorkspaceFeature()
        }

        #expect(store.state.sidebarMode == .automatic)
        await store.send(.focusModeButtonTapped) {
            $0.sidebarMode = .focus
        }
        await store.send(.focusModeButtonTapped) {
            $0.sidebarMode = .automatic
        }
    }

    @Test
    func domainModesMapAtTheSwiftUIBoundary() {
        #expect(
            WorkspaceSidebarMode.automatic.navigationSplitViewVisibility
                == .automatic
        )
        #expect(
            WorkspaceSidebarMode.visible.navigationSplitViewVisibility
                == .all
        )
        #expect(
            WorkspaceSidebarMode.focus.navigationSplitViewVisibility
                == .detailOnly
        )
    }

    private func loadChapter() throws -> Chapter {
        try ContentResourceDecoder().decode(Chapter.self, from: .chapter02)
    }

    private func loadCatalog() throws -> KnowledgeCatalog {
        try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
    }
}

private actor PersonalizationSaveSpy {
    private var revisions: [PersonalConceptRevision] = []

    func save(_ revision: PersonalConceptRevision) {
        revisions.append(revision)
    }

    func savedRevisions() -> [PersonalConceptRevision] {
        revisions
    }
}
