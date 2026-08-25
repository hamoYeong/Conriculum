import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct AppFeatureTests {
    @Test
    func initialRouteIsHome() {
        #expect(AppFeature.State().route == .home)
    }

    @Test
    func newRecordStartsAtTheOverviewRoute() async {
        let entry = HomeFeature.ChapterEntry(
            chapterID: AppFeature.chapter02ID,
            startPageID: "chapter-02-overview",
            resumePageID: nil
        )
        var initialState = AppFeature.State()
        initialState.home.chapterEntry = entry
        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.home(.startButtonTapped))
        await store.receive(.home(.delegate(.chapterRequested(
            chapterID: entry.chapterID,
            pageID: entry.startPageID
        )))) {
            $0.workspace = LearningWorkspaceFeature.State(
                chapterID: entry.chapterID,
                pageID: entry.startPageID
            )
            $0.route = .learningWorkspace(chapterID: entry.chapterID)
        }
    }

    @Test
    func savedRecordResumesAtTheLastPageRoute() async {
        let entry = HomeFeature.ChapterEntry(
            chapterID: AppFeature.chapter02ID,
            startPageID: "chapter-02-overview",
            resumePageID: "chapter-02-page-04"
        )
        var initialState = AppFeature.State()
        initialState.home.chapterEntry = entry
        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.home(.resumeButtonTapped))
        await store.receive(.home(.delegate(.chapterRequested(
            chapterID: entry.chapterID,
            pageID: "chapter-02-page-04"
        )))) {
            $0.workspace = LearningWorkspaceFeature.State(
                chapterID: entry.chapterID,
                pageID: "chapter-02-page-04"
            )
            $0.route = .learningWorkspace(chapterID: entry.chapterID)
        }
    }

    @Test
    func workspaceBackReturnsHomeAndReloadsTheLatestSnapshot() async throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let resumedPage = try #require(
            chapter.page(id: "chapter-02-page-02")
        )
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let progress = LearningProgress(
            chapterID: chapter.id,
            currentPageID: resumedPage.id,
            completedPageIDs: ["chapter-02-page-01"],
            updatedAt: timestamp
        )
        let pendingReview = KnowledgePersonalizationReview(
            candidate: KnowledgePersonalizationCandidate(
                id: "candidate-home-return",
                kind: .conceptRevision,
                conceptIDs: ["concept-value", "concept-type"],
                draft: "값과 가능한 사용을 함께 설명한다.",
                evidenceActivityID: "activity-page02-matching",
                createdAt: timestamp
            ),
            targetConceptID: "concept-value",
            activityID: "activity-page02-promotion",
            confirmationQuestion: "이 설명을 나의 지식으로 반영할까?",
            savedFields: ["나의 설명", "근거 활동 ID"]
        )
        let expectedSnapshot = HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: progress,
            responses: [],
            evidence: [],
            revisions: [],
            pendingPersonalizationReviews: [pendingReview]
        )

        var initialState = AppFeature.State()
        initialState.route = .learningWorkspace(chapterID: chapter.id)
        initialState.workspace = LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: chapter.overview.id,
            pendingPersonalizationReviews: [pendingReview]
        )
        initialState.home = HomeFeature.State(
            snapshot: HomePreviewFixtures.mock
        )

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.curriculumClient.loadChapter = { _ in chapter }
            $0.knowledgeCatalogClient.loadCatalog = { catalog }
            $0.learningRecordClient.loadProgress = { _ in progress }
            $0.learningRecordClient.loadResponses = { _ in [] }
            $0.learningRecordClient.loadEvidence = { _ in [] }
            $0.personalKnowledgeClient.loadRevisions = { _ in [] }
            $0.personalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.workspace(.homeButtonTapped))
        await store.receive(.workspace(.delegate(.homeRequested))) {
            $0.route = .home
        }
        await store.receive(.home(.workspaceReturned([pendingReview]))) {
            $0.home.pendingPersonalizationReviews = [pendingReview]
        }
        await store.receive(.home(.reloadRequested)) {
            $0.home.isLoading = true
            $0.home.loadErrorMessage = nil
        }
        await store.receive(
            .home(.loadResponse(.loaded(expectedSnapshot)))
        ) {
            $0.home.isLoading = false
            $0.home.snapshot = expectedSnapshot
            $0.home.chapterEntry = HomeFeature.ChapterEntry(
                chapterID: chapter.id,
                startPageID: chapter.overview.id,
                resumePageID: resumedPage.id
            )
        }
    }
}
