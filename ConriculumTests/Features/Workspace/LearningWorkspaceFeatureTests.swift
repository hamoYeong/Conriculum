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
        var initialState = LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: lastPageID
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
        #expect(store.state.knowledgeContext.reloadRequestCount == 0)
    }

    @Test
    func personalizationResultRefreshesOnlyTheKnowledgeChild() async throws {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageID: LearningPageID = "chapter-02-page-03"
        let expectedSnapshot = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: []
        )
        let store = TestStore(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: pageID
            )
        ) {
            LearningWorkspaceFeature()
        } withDependencies: {
            $0.curriculumClient.loadChapter = { _ in chapter }
            $0.knowledgeCatalogClient.loadCatalog = { catalog }
            $0.personalKnowledgeClient.loadRevisions = { _ in [] }
            $0.personalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.knowledgeContext(.personalizationSaved))
        await store.receive(
            .knowledgeContext(.delegate(.personalizationSaved))
        )
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
