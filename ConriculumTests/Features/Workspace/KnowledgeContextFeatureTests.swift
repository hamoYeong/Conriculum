import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct KnowledgeContextFeatureTests {
    @Test
    func initialLoadComposesTheCurrentPageSnapshot() async throws {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageID: LearningPageID = "chapter-02-page-01"
        let revision = PersonalConceptRevision(
            id: "revision-value",
            conceptID: "concept-value",
            personalTitle: nil,
            explanation: "값은 한 사례에서 하나로 정한 정보다.",
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: "activity-page01-choice",
            createdAt: .distantPast
        )
        let expectedSnapshot = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: [revision]
        )
        let store = TestStore(
            initialState: KnowledgeContextFeature.State(
                chapterID: chapter.id,
                currentPageID: pageID
            )
        ) {
            KnowledgeContextFeature()
        } withDependencies: {
            $0.curriculumClient.loadChapter = { _ in chapter }
            $0.knowledgeCatalogClient.loadCatalog = { catalog }
            $0.personalKnowledgeClient.loadRevisions = { conceptID in
                conceptID == revision.conceptID ? [revision] : []
            }
        }

        await store.send(.task)
        await store.receive(.reloadRequested(.initial)) {
            $0.isLoading = true
            $0.lastReloadReason = .initial
            $0.reloadRequestCount = 1
        }
        await store.receive(.loadResponse(.loaded(expectedSnapshot))) {
            $0.snapshot = expectedSnapshot
            $0.isLoading = false
        }
    }

    @Test
    func pageChangeClearsTheOldSnapshotAndLoadsTheNewScope() async throws {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageOneID: LearningPageID = "chapter-02-page-01"
        let pageFiveID: LearningPageID = "chapter-02-page-05"
        let oldSnapshot = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageOneID,
            revisions: []
        )
        let expectedSnapshot = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageFiveID,
            revisions: []
        )
        let store = TestStore(
            initialState: KnowledgeContextFeature.State(
                chapterID: chapter.id,
                currentPageID: pageOneID,
                snapshot: oldSnapshot
            )
        ) {
            KnowledgeContextFeature()
        } withDependencies: {
            $0.curriculumClient.loadChapter = { _ in chapter }
            $0.knowledgeCatalogClient.loadCatalog = { catalog }
            $0.personalKnowledgeClient.loadRevisions = { _ in [] }
        }

        await store.send(.pageChanged(pageFiveID)) {
            $0.currentPageID = pageFiveID
            $0.snapshot = nil
        }
        await store.receive(.reloadRequested(.pageChanged)) {
            $0.isLoading = true
            $0.lastReloadReason = .pageChanged
            $0.reloadRequestCount = 1
        }
        await store.receive(.loadResponse(.loaded(expectedSnapshot))) {
            $0.snapshot = expectedSnapshot
            $0.isLoading = false
        }
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
