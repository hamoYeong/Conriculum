import ComposableArchitecture
import Foundation
import Testing
@testable import Conriculum

@MainActor
struct HomeFeatureTests {
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
            $0.curriculumClient.loadChapter = { _ in chapter }
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
        await store.receive(.loadResponse(.loaded(expectedSnapshot))) {
            $0.isLoading = false
            $0.snapshot = expectedSnapshot
            $0.chapterEntry = HomeFeature.ChapterEntry(
                chapterID: chapter.id,
                startPageID: chapter.overview.id,
                resumePageID: page.id
            )
        }
    }
}

private extension HomeSnapshot {
    static var mock: Self { HomePreviewFixtures.mock }
}
