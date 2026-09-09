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
    func pageRequestOpensCurrentLearningRoute() async {
        let pageID = "v2.s1.c1.p1"
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.home(.delegate(.pageRequested(pageID)))) {
            $0.learning = LearningFeature.State(pageID: pageID)
            $0.route = .learning(pageID: pageID)
        }
    }

    @Test
    func anyAvailableChapterCanStartAtItsOverviewRoute() async {
        let entry = HomeFeature.V1ChapterEntry(
            chapterID: "chapter-03",
            startPageID: "chapter-03-overview",
            resumePageID: nil
        )
        var initialState = AppFeature.State()
        initialState.home.v1ChapterEntry = entry
        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.home(.v1StartButtonTapped))
        await store.receive(.home(.delegate(.v1ChapterRequested(
            chapterID: entry.chapterID,
            pageID: entry.startPageID
        )))) {
            $0.v1Workspace = V1LearningWorkspaceFeature.State(
                chapterID: entry.chapterID,
                pageID: entry.startPageID
            )
            $0.route = .v1Learning(chapterID: entry.chapterID)
        }
    }

    @Test
    func savedRecordResumesAtTheLastPageRoute() async {
        let entry = HomeFeature.V1ChapterEntry(
            chapterID: "chapter-02",
            startPageID: "chapter-02-overview",
            resumePageID: "chapter-02-page-04"
        )
        var initialState = AppFeature.State()
        initialState.home.v1ChapterEntry = entry
        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.home(.v1ResumeButtonTapped))
        await store.receive(.home(.delegate(.v1ChapterRequested(
            chapterID: entry.chapterID,
            pageID: "chapter-02-page-04"
        )))) {
            $0.v1Workspace = V1LearningWorkspaceFeature.State(
                chapterID: entry.chapterID,
                pageID: "chapter-02-page-04"
            )
            $0.route = .v1Learning(chapterID: entry.chapterID)
        }
    }

    @Test
    func homeKnowledgeRequestOpensTheKnowledgeSystem() async {
        var state = AppFeature.State()
        state.home.selectedContentVersion = .v1
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.home(.knowledgeSystemButtonTapped))
        await store.receive(.home(.delegate(.knowledgeSystemRequested))) {
            $0.knowledgeSystem = KnowledgeSystemFeature.State()
            $0.route = .knowledgeSystem
        }
    }

    @Test
    func currentHomeKnowledgeRequestOpensTheCurrentBookshelf() async {
        var state = AppFeature.State()
        state.home.selectedContentVersion = .v2
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.home(.knowledgeSystemButtonTapped))
        await store.receive(.home(.delegate(.knowledgeSystemRequested))) {
            $0.knowledgeSystem = KnowledgeSystemFeature.State(
                contentVersion: .v2
            )
            $0.route = .knowledgeSystem
        }
    }

    @Test
    func knowledgeSystemBackReturnsHomeAndReleasesItsState() async {
        var initialState = AppFeature.State()
        initialState.route = .knowledgeSystem
        initialState.knowledgeSystem = KnowledgeSystemFeature.State()
        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.knowledgeSystem(.homeButtonTapped))
        await store.receive(.knowledgeSystem(.delegate(.homeRequested))) {
            $0.route = .home
            $0.knowledgeSystem = nil
        }
    }

    @Test
    func pendingCandidateReturnsToTheWorkspaceWithoutBeingPersisted() async {
        let review = V1KnowledgePersonalizationReview(
            candidate: KnowledgePersonalizationCandidate(
                id: "candidate-app-round-trip",
                kind: .conceptRevision,
                conceptIDs: ["concept-value", "concept-type"],
                draft: "값과 가능한 사용을 함께 설명한다.",
                evidenceActivityID: "activity-page02-matching",
                createdAt: Date(timeIntervalSince1970: 1_725_782_400)
            ),
            targetConceptID: "concept-value",
            activityID: "activity-page02-promotion",
            confirmationQuestion: "이 설명을 나의 지식으로 반영할까?",
            savedFields: ["나의 설명", "근거 활동 ID"]
        )
        let entry = HomeFeature.V1ChapterEntry(
            chapterID: "chapter-02",
            startPageID: "chapter-02-overview",
            resumePageID: "chapter-02-page-02"
        )
        var initialState = AppFeature.State()
        initialState.home.v1ChapterEntry = entry
        initialState.home.v1PendingPersonalizationReviews = [review]
        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.home(.v1ResumeButtonTapped))
        await store.receive(.home(.delegate(.v1ChapterRequested(
            chapterID: entry.chapterID,
            pageID: "chapter-02-page-02"
        )))) {
            $0.v1Workspace = V1LearningWorkspaceFeature.State(
                chapterID: entry.chapterID,
                pageID: "chapter-02-page-02",
                v1PendingPersonalizationReviews: [review]
            )
            $0.route = .v1Learning(chapterID: entry.chapterID)
        }

        #expect(
            store.state.v1Workspace?.v1PendingPersonalizationReviews == [review]
        )
        #expect(
            store.state.v1Workspace?.knowledgeContext
                .v1PendingPersonalizationReviews == [review]
        )
    }

    @Test
    func workspaceBackReturnsHomeAndReloadsTheLatestSnapshot() async throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(V1Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let resumedPage = try #require(
            chapter.page(id: "chapter-02-page-02")
        )
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let progress = V1LearningProgress(
            chapterID: chapter.id,
            currentPageID: resumedPage.id,
            completedPageIDs: ["chapter-02-page-01"],
            updatedAt: timestamp
        )
        let pendingReview = V1KnowledgePersonalizationReview(
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
        let expectedSnapshot = V1HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: progress,
            responses: [],
            evidence: [],
            revisions: [],
            pendingPersonalizationReviews: [pendingReview]
        )

        var initialState = AppFeature.State()
        initialState.route = .v1Learning(chapterID: chapter.id)
        initialState.v1Workspace = V1LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: chapter.overview.id,
            v1PendingPersonalizationReviews: [pendingReview]
        )
        initialState.home = HomeFeature.State(
            v1Snapshot: V1HomePreviewFixtures.mock
        )

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.v1CurriculumClient.loadChapters = { [chapter] }
            $0.v1KnowledgeCatalogClient.loadCatalog = { catalog }
            $0.v1LearningRecordClient.loadProgress = { _ in progress }
            $0.v1LearningRecordClient.loadResponses = { _ in [] }
            $0.v1LearningRecordClient.loadEvidence = { _ in [] }
            $0.v1PersonalKnowledgeClient.loadRevisions = { _ in [] }
            $0.v1PersonalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.v1Workspace(.homeButtonTapped))
        await store.receive(.v1Workspace(.delegate(.homeRequested))) {
            $0.route = .home
        }
        await store.receive(.home(.v1WorkspaceReturned([pendingReview]))) {
            $0.home.v1PendingPersonalizationReviews = [pendingReview]
        }
        await store.receive(.home(.reloadRequested)) {
            $0.home.v1IsLoading = true
            $0.home.v1LoadErrorMessage = nil
        }
        await store.receive(
            .home(.v1LoadResponse(.loaded(expectedSnapshot)))
        ) {
            $0.home.v1IsLoading = false
            $0.home.v1Snapshot = expectedSnapshot
            $0.home.v1ChapterEntry = HomeFeature.V1ChapterEntry(
                chapterID: chapter.id,
                startPageID: chapter.overview.id,
                resumePageID: resumedPage.id
            )
        }
    }
}
