import ComposableArchitecture
import Foundation
import Testing
@testable import Conriculum

@MainActor
struct HomeFeatureTests {
    @Test
    func freshHomeResumesMostRecentlySavedChapterAndOffersEveryChapter() async throws {
        let decoder = ContentResourceDecoder()
        let second = try decoder.decode(Chapter.self, from: .chapter02)
        let third = try decoder.decode(Chapter.self, from: .chapter(stageNumber: 1, chapterNumber: 3))
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let progress = LearningProgress(chapterID: third.id, currentPageID: third.overview.id,
            completedPageIDs: [], updatedAt: Date(timeIntervalSince1970: 100))
        let expected = HomeSnapshotComposer().compose(chapter: third, catalog: catalog,
            progress: progress, responses: [], evidence: [], revisions: [],
            availableChapters: [second, third], progressByChapter: [third.id: progress])
        let store = TestStore(initialState: HomeFeature.State()) { HomeFeature() } withDependencies: {
            $0.curriculumClient.loadChapters = { [second, third] }
            $0.knowledgeCatalogClient.loadCatalog = { catalog }
            $0.learningRecordClient.loadProgress = { $0 == third.id ? progress : nil }
            $0.learningRecordClient.loadResponses = { _ in [] }
            $0.learningRecordClient.loadEvidence = { _ in [] }
            $0.personalKnowledgeClient.loadRevisions = { _ in [] }
            $0.personalKnowledgeClient.loadRelations = { _ in [] }
        }
        await store.send(.task) { $0.isLoading = true }
        await store.receive(.loadResponse(.loaded(expected)), timeout: .seconds(10)) {
            $0.isLoading = false
            $0.snapshot = expected
            $0.chapterEntry = .init(chapterID: third.id, startPageID: third.overview.id, resumePageID: third.overview.id)
        }
        await store.send(.chapterSelected(second.id))
        await store.receive(.delegate(.chapterRequested(chapterID: second.id, pageID: second.overview.id)))
        await store.send(.chapterSelected("missing-chapter"))
    }

    @Test
    func reloadKeepsTheCurrentlySelectedChapterWhenSeveralAreAvailable()
        async throws
    {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let earlierChapter = Chapter(
            id: "chapter-01",
            stageID: chapter.stageID,
            order: 1,
            title: "더 이른 챕터",
            summary: chapter.summary,
            overview: chapter.overview,
            pages: chapter.pages
        )
        let expectedSnapshot = HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: nil,
            responses: [],
            evidence: [],
            revisions: [],
            availableChapters: [earlierChapter, chapter]
        )
        let store = TestStore(
            initialState: HomeFeature.State(snapshot: .mock)
        ) {
            HomeFeature()
        } withDependencies: {
            $0.curriculumClient.loadChapters = { [earlierChapter, chapter] }
            $0.knowledgeCatalogClient.loadCatalog = { catalog }
            $0.learningRecordClient.loadProgress = { _ in nil }
            $0.learningRecordClient.loadResponses = { _ in [] }
            $0.learningRecordClient.loadEvidence = { _ in [] }
            $0.personalKnowledgeClient.loadRevisions = { _ in [] }
            $0.personalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.reloadRequested) {
            $0.isLoading = true
            $0.loadErrorMessage = nil
        }
        await store.receive(.loadResponse(.loaded(expectedSnapshot)), timeout: .seconds(10)) {
            $0.isLoading = false
            $0.snapshot = expectedSnapshot
            $0.chapterEntry = HomeFeature.ChapterEntry(
                chapterID: chapter.id,
                startPageID: chapter.overview.id,
                resumePageID: nil
            )
        }
    }

    @Test
    func loadComposesStoredRecordsAheadOfPreviewPlaceholder() async throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let page = try #require(chapter.page(id: "chapter-02-page-02"))
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let progress = LearningProgress(
            chapterID: chapter.id,
            currentPageID: page.id,
            completedPageIDs: ["chapter-02-page-01"],
            updatedAt: timestamp
        )
        let response = ActivityResponse(
            id: "stored-response",
            activityID: "activity-page02-matching",
            pageID: page.id,
            fields: [ActivityResponseField(key: "pairs", values: ["String:text"])],
            recordedAt: timestamp
        )
        let evidence = LearningEvidence(
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
        let expectedSnapshot = HomeSnapshotComposer().compose(
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
                snapshot: .mock,
                usesSnapshotAsPlaceholder: true
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.curriculumClient.loadChapters = { [chapter] }
            $0.knowledgeCatalogClient.loadCatalog = { catalog }
            $0.learningRecordClient.loadProgress = { _ in progress }
            $0.learningRecordClient.loadResponses = { pageID in
                pageID == page.id ? [response] : []
            }
            $0.learningRecordClient.loadEvidence = { pageID in
                pageID == page.id ? [evidence] : []
            }
            $0.personalKnowledgeClient.loadRevisions = { conceptID in
                conceptID == revision.conceptID ? [revision] : []
            }
            $0.personalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.task) {
            $0.isLoading = true
            $0.loadErrorMessage = nil
        }
        await store.receive(.loadResponse(.loaded(expectedSnapshot)), timeout: .seconds(10)) {
            $0.isLoading = false
            $0.snapshot = expectedSnapshot
            $0.chapterEntry = HomeFeature.ChapterEntry(
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
        let chapter = try decoder.decode(Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let previousSnapshot = HomePreviewFixtures.mock
        let store = TestStore(
            initialState: HomeFeature.State(snapshot: previousSnapshot)
        ) {
            HomeFeature()
        } withDependencies: {
            $0.curriculumClient.loadChapters = { [chapter] }
            $0.knowledgeCatalogClient.loadCatalog = { catalog }
            $0.learningRecordClient.loadProgress = { _ in nil }
            $0.learningRecordClient.loadResponses = { _ in [] }
            $0.learningRecordClient.loadEvidence = { _ in [] }
            $0.personalKnowledgeClient.loadRevisions = { _ in
                throw NSError(
                    domain: "HomeFeatureTests",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "테스트 Home 개인 지식 조회 실패"
                    ]
                )
            }
            $0.personalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.reloadRequested) {
            $0.isLoading = true
        }
        await store.receive(.loadResponse(.failed(
            message: "테스트 Home 개인 지식 조회 실패"
        ))) {
            $0.isLoading = false
            $0.loadErrorMessage = "테스트 Home 개인 지식 조회 실패"
        }

        #expect(store.state.snapshot == previousSnapshot)
    }
}

private extension HomeSnapshot {
    static var mock: Self { HomePreviewFixtures.mock }
}
