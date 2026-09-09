import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct V1LearningWorkspaceFeatureTests {
    @Test
    func savedPageNavigationRefreshesTheKnowledgeContext() async throws {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageOne = try #require(chapter.progressPageIDs.first)
        let pageTwo = try #require(chapter.progressPageIDs.dropFirst().first)
        let expectedSnapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageTwo,
            revisions: []
        )
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let progress = V1LearningProgress(
            chapterID: chapter.id,
            currentPageID: pageTwo,
            completedPageIDs: [],
            updatedAt: timestamp
        )
        var initialState = V1LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageOne
        )
        initialState.chapter.chapter = chapter
        let store = TestStore(
            initialState: initialState
        ) {
            V1LearningWorkspaceFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.v1LearningRecordClient.saveProgress = { _ in }
            $0.v1CurriculumClient.loadChapter = { _ in chapter }
            $0.v1KnowledgeCatalogClient.loadCatalog = { catalog }
            $0.v1PersonalKnowledgeClient.loadRevisions = { _ in [] }
            $0.v1PersonalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.chapter(.nextButtonTapped)) {
            $0.chapter.isSavingNavigation = true
        }
        await store.receive(.chapter(.navigationResponse(.saved(
            destination: .page(pageTwo),
            progress: progress,
            drafts: [],
            responses: []
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
            V1ActivityResponseField(
                key: "reason",
                values: ["저장 실패 뒤에도 남아야 하는 초안"]
            )
        ]
        let responseUUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000002"
        )!
        let draft = V1ChapterLearningFeature.ActivityDraft(
            responseID: ActivityResponseID(
                rawValue: responseUUID.uuidString.lowercased()
            ),
            activityID: activityID,
            fields: fields
        )
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let clock = TestClock()
        var initialState = V1LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageOne
        )
        initialState.chapter.chapter = chapter
        let store = TestStore(initialState: initialState) {
            V1LearningWorkspaceFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.uuid = .constant(responseUUID)
            $0.continuousClock = clock
            $0.v1LearningRecordClient.saveResponse = { _ in }
            $0.v1LearningRecordClient.saveProgress = { _ in
                throw NSError(
                    domain: "V1LearningWorkspaceFeatureTests",
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
        let progress = V1LearningProgress(
            chapterID: chapter.id,
            currentPageID: lastPageID,
            completedPageIDs: [],
            updatedAt: timestamp
        )
        let pendingReview = V1KnowledgePersonalizationReview(
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
            savedFields: ["나의 설명", "근거 학습 활동"]
        )
        var initialState = V1LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: lastPageID,
            v1PendingPersonalizationReviews: [pendingReview]
        )
        initialState.chapter.chapter = chapter
        let store = TestStore(initialState: initialState) {
            V1LearningWorkspaceFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.v1LearningRecordClient.saveProgress = { _ in }
        }

        await store.send(.chapter(.nextButtonTapped)) {
            $0.chapter.isSavingNavigation = true
        }
        await store.receive(.chapter(.navigationResponse(.saved(
            destination: .completionSummary,
            progress: progress,
            drafts: [],
            responses: []
        )))) {
            $0.chapter.isSavingNavigation = false
            $0.chapter.isShowingCompletionSummary = true
        }

        #expect(store.state.chapter.currentPageID == lastPageID)
        #expect(store.state.chapter.completedPageIDs.isEmpty)
        #expect(store.state.v1PendingPersonalizationReviews == [pendingReview])
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
        let pendingReview = V1KnowledgePersonalizationReview(
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
            savedFields: ["나의 설명", "근거 학습 활동"]
        )
        let expectedSnapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: [revision],
            relations: [relation]
        )
        let store = TestStore(
            initialState: V1LearningWorkspaceFeature.State(
                chapterID: "chapter-02",
                pageID: pageID,
                v1PendingPersonalizationReviews: [pendingReview]
            )
        ) {
            V1LearningWorkspaceFeature()
        } withDependencies: {
            $0.v1CurriculumClient.loadChapter = { _ in chapter }
            $0.v1KnowledgeCatalogClient.loadCatalog = { catalog }
            $0.v1PersonalKnowledgeClient.loadRevisions = { conceptID in
                conceptID == revision.conceptID ? [revision] : []
            }
            $0.v1PersonalKnowledgeClient.loadRelations = { conceptID in
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
            $0.v1PendingPersonalizationReviews = []
            $0.knowledgeContext.v1PendingPersonalizationReviews = []
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
        let snapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: []
        )
        let review = V1KnowledgePersonalizationReview(
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
            savedFields: ["나의 설명", "근거 학습 활동"]
        )
        let item = try #require(snapshot.directConcepts.first {
            $0.id == review.targetConceptID
        })
        var initialState = V1LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageID,
            v1PendingPersonalizationReviews: [review]
        )
        initialState.chapter.chapter = chapter
        initialState.chapter.knowledgeCatalog = catalog
        initialState.knowledgeContext.snapshot = snapshot
        initialState.knowledgeContext.inspector = V1ConceptInspectorFeature.State(
            sourcePageTitle: snapshot.pageTitle,
            item: item,
            availableConcepts: snapshot.availableConcepts,
            baseRelations: snapshot.baseRelations,
            personalRelations: snapshot.personalRelations,
            relationCreationContract: snapshot.relationCreationContract,
            personalizationReview: review
        )
        let store = TestStore(initialState: initialState) {
            V1LearningWorkspaceFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.uuid = .constant(UUID(
                uuidString: "00000000-0000-0000-0000-000000000085"
            )!)
            $0.v1PersonalKnowledgeClient.saveRevision = { _ in
                throw NSError(
                    domain: "V1LearningWorkspaceFeatureTests",
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

        #expect(store.state.v1PendingPersonalizationReviews == [review])
        #expect(
            store.state.knowledgeContext.v1PendingPersonalizationReviews
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
        let snapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: []
        )
        let request = V1PersonalRelationDraftRequest(
            sourceConceptID: "concept-related-value-grouping",
            targetConceptID: "concept-type-modeling",
            statement: "값 묶기의 경계는 타입 책임으로 이어진다.",
            reason: "관련 값을 구조로 보존하기 때문이다.",
            evidenceActivityID: "activity-page07-role-sorting"
        )
        let componentAction = V1PersonalKnowledgeComponentAction
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
        var expectedInspector = V1ConceptInspectorFeature.State(
            sourcePageTitle: snapshot.pageTitle,
            item: item,
            availableConcepts: snapshot.availableConcepts,
            baseRelations: snapshot.baseRelations,
            personalRelations: snapshot.personalRelations,
            relationCreationContract: contract
        )
        expectedInspector.relationEditor = V1PersonalRelationEditorFeature.State(
            request: request,
            contract: contract,
            availableConcepts: snapshot.availableConcepts
        )
        var initialState = V1LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageID
        )
        initialState.chapter.chapter = chapter
        initialState.chapter.knowledgeCatalog = catalog
        initialState.knowledgeContext.snapshot = snapshot
        let store = TestStore(initialState: initialState) {
            V1LearningWorkspaceFeature()
        }

        await store.send(.chapter(.delegate(.personalKnowledge(
            componentAction
        ))))
        await store.receive(.knowledgeContext(.relationDraftRequested(
            request
        ))) {
            $0.knowledgeContext.inspector = expectedInspector
            $0.isInspectorPresented = true
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
        let snapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: []
        )
        let responseDraft = V1ChapterLearningFeature.ActivityDraft(
            responseID: "response-page05-promotion",
            activityID: activityID,
            fields: [
                V1ActivityResponseField(
                    key: V1LearningActivityFieldKey.personalExpression,
                    values: [expression]
                ),
                V1ActivityResponseField(
                    key: V1LearningActivityFieldKey
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
        let review = V1KnowledgePersonalizationReview(
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
                "근거 학습 활동",
                "수정 시각",
            ]
        )
        let item = try #require(snapshot.directConcepts.first {
            $0.id == targetConceptID
        })
        let expectedInspector = V1ConceptInspectorFeature.State(
            sourcePageTitle: snapshot.pageTitle,
            item: item,
            availableConcepts: snapshot.availableConcepts,
            baseRelations: snapshot.baseRelations,
            personalRelations: snapshot.personalRelations,
            relationCreationContract: snapshot.relationCreationContract,
            personalizationReview: review
        )
        let saveSpy = PersonalizationSaveSpy()
        var initialState = V1LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageID
        )
        initialState.chapter.chapter = chapter
        initialState.chapter.knowledgeCatalog = catalog
        initialState.chapter.activityDrafts[activityID] = responseDraft
        initialState.chapter.activitySaveStates[activityID] = .saved(timestamp)
        initialState.knowledgeContext.snapshot = snapshot
        let store = TestStore(initialState: initialState) {
            V1LearningWorkspaceFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.uuid = .constant(candidateUUID)
            $0.v1PersonalKnowledgeClient.saveRevision = { revision in
                await saveSpy.save(revision)
            }
        }
        let componentAction = V1PersonalKnowledgeComponentAction
            .promotionReviewRequested(
                activityID: activityID,
                targetConceptID: targetConceptID,
                expression: "  \(expression)  "
            )

        await store.send(.chapter(.delegate(.personalKnowledge(
            componentAction
        )))) {
            $0.v1PendingPersonalizationReviews = [review]
            $0.knowledgeContext.v1PendingPersonalizationReviews = [review]
        }
        await store.receive(.knowledgeContext(
            .personalizationReviewRequested(review)
        )) {
            $0.knowledgeContext.inspector = expectedInspector
            $0.isInspectorPresented = true
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
            $0.isInspectorPresented = false
        }
        #expect(store.state.v1PendingPersonalizationReviews == [review])

        await store.send(.chapter(.delegate(.personalKnowledge(
            .promotionCancelled(activityID)
        )))) {
            $0.v1PendingPersonalizationReviews = []
            $0.knowledgeContext.v1PendingPersonalizationReviews = []
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
            initialState: V1LearningWorkspaceFeature.State(
                chapterID: "chapter-02",
                pageID: "chapter-02-overview"
            )
        ) {
            V1LearningWorkspaceFeature()
        }

        await store.send(.homeButtonTapped)
        await store.receive(.delegate(.homeRequested))
    }

    @Test
    func focusModeHidesBothPanelsAndRestoresTheirPreviousState()
        async throws
    {
        var initialState = try workspaceStateWithInspector(
            pageID: "chapter-02-page-03"
        )
        initialState.sidebarMode = .visible
        initialState.isInspectorPresented = true
        let store = TestStore(initialState: initialState) {
            V1LearningWorkspaceFeature()
        }

        await store.send(.focusModeButtonTapped) {
            $0.isFocusModeEnabled = true
            $0.isInspectorPresented = false
            $0.wasInspectorPresentedBeforeFocus = true
        }
        await store.send(.focusModeButtonTapped) {
            $0.isFocusModeEnabled = false
            $0.isInspectorPresented = true
        }

        #expect(store.state.sidebarMode == .visible)
    }

    @Test
    func automaticIsTheDefaultAndFocusDoesNotPersistAcrossNewState() async {
        let store = TestStore(
            initialState: V1LearningWorkspaceFeature.State(
                chapterID: "chapter-02",
                pageID: "chapter-02-overview"
            )
        ) {
            V1LearningWorkspaceFeature()
        }

        #expect(store.state.sidebarMode == .automatic)
        await store.send(.focusModeButtonTapped) {
            $0.isFocusModeEnabled = true
        }
        await store.send(.focusModeButtonTapped) {
            $0.isFocusModeEnabled = false
        }
    }

    @Test
    func toolbarPanelButtonsControlSidebarAndInspectorIndependently()
        async throws
    {
        var initialState = try workspaceStateWithInspector(
            pageID: "chapter-02-page-03"
        )
        initialState.sidebarMode = .visible
        initialState.isInspectorPresented = true
        let store = TestStore(initialState: initialState) {
            V1LearningWorkspaceFeature()
        }

        await store.send(.sidebarVisibilityButtonTapped) {
            $0.sidebarMode = .hidden
        }
        await store.send(.sidebarVisibilityButtonTapped) {
            $0.sidebarMode = .visible
        }
        await store.send(.inspectorVisibilityButtonTapped) {
            $0.isInspectorPresented = false
        }
        await store.send(.inspectorVisibilityButtonTapped) {
            $0.isInspectorPresented = true
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
            WorkspaceSidebarMode.hidden.navigationSplitViewVisibility
                == .detailOnly
        )
        #expect(
            WorkspaceSidebarMode.automatic
                .hidesKnowledgeContextFromAccessibility == false
        )
        #expect(
            WorkspaceSidebarMode.visible
                .hidesKnowledgeContextFromAccessibility == false
        )
        #expect(
            WorkspaceSidebarMode.hidden
                .hidesKnowledgeContextFromAccessibility
        )
    }

    private func workspaceStateWithInspector(
        pageID: LearningPageID
    ) throws -> V1LearningWorkspaceFeature.State {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let snapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: []
        )
        let item = try #require(snapshot.directConcepts.first)
        var state = V1LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageID
        )
        state.chapter.chapter = chapter
        state.chapter.knowledgeCatalog = catalog
        state.knowledgeContext.snapshot = snapshot
        state.knowledgeContext.inspector = V1ConceptInspectorFeature.State(
            sourcePageTitle: snapshot.pageTitle,
            item: item,
            availableConcepts: snapshot.availableConcepts,
            baseRelations: snapshot.baseRelations,
            personalRelations: snapshot.personalRelations,
            relationCreationContract: snapshot.relationCreationContract
        )
        return state
    }

    private func loadChapter() throws -> V1Chapter {
        try ContentResourceDecoder().decode(V1Chapter.self, from: .chapter02)
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
