import ComposableArchitecture
import Foundation
import Testing
@testable import Conriculum

@MainActor
struct HomeFeatureTests {
    @Test
    func freshHomeResumesMostRecentlySavedChapterAndOffersEveryChapter() async throws {
        let decoder = ContentResourceDecoder()
        let second = try decoder.decode(V1Chapter.self, from: .chapter02)
        let third = try decoder.decode(V1Chapter.self, from: .chapter(stageNumber: 1, chapterNumber: 3))
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let progress = V1LearningProgress(chapterID: third.id, currentPageID: third.overview.id,
            completedPageIDs: [], updatedAt: Date(timeIntervalSince1970: 100))
        let expected = V1HomeSnapshotComposer().compose(chapter: third, catalog: catalog,
            progress: progress, responses: [], evidence: [], revisions: [],
            availableChapters: [second, third], progressByChapter: [third.id: progress])
        let store = TestStore(initialState: HomeFeature.State()) { HomeFeature() } withDependencies: {
            $0.v1CurriculumClient.loadChapters = { [second, third] }
            $0.v1KnowledgeCatalogClient.loadCatalog = { catalog }
            $0.v1LearningRecordClient.loadProgress = { $0 == third.id ? progress : nil }
            $0.v1LearningRecordClient.loadResponses = { _ in [] }
            $0.v1LearningRecordClient.loadEvidence = { _ in [] }
            $0.v1PersonalKnowledgeClient.loadRevisions = { _ in [] }
            $0.v1PersonalKnowledgeClient.loadRelations = { _ in [] }
        }
        await store.send(.task) { $0.v1IsLoading = true }
        await store.receive(.v1LoadResponse(.loaded(expected)), timeout: .seconds(10)) {
            $0.v1IsLoading = false
            $0.v1Snapshot = expected
            $0.v1ChapterEntry = .init(chapterID: third.id, startPageID: third.overview.id, resumePageID: third.overview.id)
        }
        await store.send(.v1ChapterSelected(second.id))
        await store.receive(.delegate(.v1ChapterRequested(chapterID: second.id, pageID: second.overview.id)))
        await store.send(.v1ChapterSelected("missing-chapter"))
    }

    @Test
    func reloadKeepsTheCurrentlySelectedChapterWhenSeveralAreAvailable()
        async throws
    {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(V1Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let earlierChapter = V1Chapter(
            id: "chapter-01",
            stageID: chapter.stageID,
            order: 1,
            title: "더 이른 챕터",
            summary: chapter.summary,
            overview: chapter.overview,
            pages: chapter.pages
        )
        let expectedSnapshot = V1HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: nil,
            responses: [],
            evidence: [],
            revisions: [],
            availableChapters: [earlierChapter, chapter]
        )
        let store = TestStore(
            initialState: HomeFeature.State(v1Snapshot: .mock)
        ) {
            HomeFeature()
        } withDependencies: {
            $0.v1CurriculumClient.loadChapters = { [earlierChapter, chapter] }
            $0.v1KnowledgeCatalogClient.loadCatalog = { catalog }
            $0.v1LearningRecordClient.loadProgress = { _ in nil }
            $0.v1LearningRecordClient.loadResponses = { _ in [] }
            $0.v1LearningRecordClient.loadEvidence = { _ in [] }
            $0.v1PersonalKnowledgeClient.loadRevisions = { _ in [] }
            $0.v1PersonalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.reloadRequested) {
            $0.v1IsLoading = true
            $0.v1LoadErrorMessage = nil
        }
        await store.receive(.v1LoadResponse(.loaded(expectedSnapshot)), timeout: .seconds(10)) {
            $0.v1IsLoading = false
            $0.v1Snapshot = expectedSnapshot
            $0.v1ChapterEntry = HomeFeature.V1ChapterEntry(
                chapterID: chapter.id,
                startPageID: chapter.overview.id,
                resumePageID: nil
            )
        }
    }

    @Test
    func loadComposesStoredRecordsAheadOfPreviewPlaceholder() async throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(V1Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let page = try #require(chapter.page(id: "chapter-02-page-02"))
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let progress = V1LearningProgress(
            chapterID: chapter.id,
            currentPageID: page.id,
            completedPageIDs: ["chapter-02-page-01"],
            updatedAt: timestamp
        )
        let response = V1ActivityResponse(
            id: "stored-response",
            activityID: "activity-page02-matching",
            pageID: page.id,
            fields: [V1ActivityResponseField(key: "pairs", values: ["String:text"])],
            recordedAt: timestamp
        )
        let evidence = V1LearningEvidence(
            id: "stored-evidence",
            kind: .reasoningExplanation,
            pageID: page.id,
            activityID: response.activityID,
            responseID: response.id,
            note: "저장된 판단 설명",
            recordedAt: timestamp
        )
        let revision = PersonalConceptRevision(
            id: "stored-revision",
            conceptID: "concept-type",
            personalTitle: "값이 할 수 있는 일의 약속",
            explanation: "저장된 타입 설명",
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: response.activityID,
            createdAt: timestamp
        )
        let expectedSnapshot = V1HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: progress,
            responses: [response],
            evidence: [evidence],
            revisions: [revision],
            placeholder: .mock
        )
        let store = TestStore(
            initialState: HomeFeature.State(
                v1Snapshot: .mock,
                usesSnapshotAsPlaceholder: true
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.v1CurriculumClient.loadChapters = { [chapter] }
            $0.v1KnowledgeCatalogClient.loadCatalog = { catalog }
            $0.v1LearningRecordClient.loadProgress = { _ in progress }
            $0.v1LearningRecordClient.loadResponses = { pageID in
                pageID == page.id ? [response] : []
            }
            $0.v1LearningRecordClient.loadEvidence = { pageID in
                pageID == page.id ? [evidence] : []
            }
            $0.v1PersonalKnowledgeClient.loadRevisions = { conceptID in
                conceptID == revision.conceptID ? [revision] : []
            }
            $0.v1PersonalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.task) {
            $0.v1IsLoading = true
            $0.v1LoadErrorMessage = nil
        }
        await store.receive(.v1LoadResponse(.loaded(expectedSnapshot)), timeout: .seconds(10)) {
            $0.v1IsLoading = false
            $0.v1Snapshot = expectedSnapshot
            $0.v1ChapterEntry = HomeFeature.V1ChapterEntry(
                chapterID: chapter.id,
                startPageID: chapter.overview.id,
                resumePageID: page.id
            )
        }
    }

    @Test
    func personalKnowledgeLoadFailureKeepsTheLastSuccessfulSummary()
        async throws
    {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(V1Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let previousSnapshot = V1HomePreviewFixtures.mock
        let store = TestStore(
            initialState: HomeFeature.State(v1Snapshot: previousSnapshot)
        ) {
            HomeFeature()
        } withDependencies: {
            $0.v1CurriculumClient.loadChapters = { [chapter] }
            $0.v1KnowledgeCatalogClient.loadCatalog = { catalog }
            $0.v1LearningRecordClient.loadProgress = { _ in nil }
            $0.v1LearningRecordClient.loadResponses = { _ in [] }
            $0.v1LearningRecordClient.loadEvidence = { _ in [] }
            $0.v1PersonalKnowledgeClient.loadRevisions = { _ in
                throw NSError(
                    domain: "HomeFeatureTests",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "테스트 Home 개인 지식 조회 실패"
                    ]
                )
            }
            $0.v1PersonalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.reloadRequested) {
            $0.v1IsLoading = true
        }
        await store.receive(.v1LoadResponse(.failed(
            message: "테스트 Home 개인 지식 조회 실패"
        ))) {
            $0.v1IsLoading = false
            $0.v1LoadErrorMessage = "테스트 Home 개인 지식 조회 실패"
        }

        #expect(store.state.v1Snapshot == previousSnapshot)
    }
}

private extension V1HomeSnapshot {
    static var mock: Self { V1HomePreviewFixtures.mock }
}
