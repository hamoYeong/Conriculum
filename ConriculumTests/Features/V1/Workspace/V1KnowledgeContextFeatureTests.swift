import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct V1KnowledgeContextFeatureTests {
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
        let relation = PersonalKnowledgeRelation(
            id: "personal-relation-value-type",
            sourceConceptID: "concept-value",
            targetConceptID: "concept-type",
            statement: "값은 타입이 허용하는 사용과 연결된다.",
            reason: "타입이 가능한 연산을 정하기 때문이다.",
            evidenceActivityID: "activity-page02-matching",
            createdAt: .distantPast
        )
        let expectedSnapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: [revision],
            relations: [relation]
        )
        let store = TestStore(
            initialState: V1KnowledgeContextFeature.State(
                chapterID: chapter.id,
                currentPageID: pageID
            )
        ) {
            V1KnowledgeContextFeature()
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
        let oldSnapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageOneID,
            revisions: []
        )
        let expectedSnapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageFiveID,
            revisions: []
        )
        let store = TestStore(
            initialState: V1KnowledgeContextFeature.State(
                chapterID: chapter.id,
                currentPageID: pageOneID,
                snapshot: oldSnapshot
            )
        ) {
            V1KnowledgeContextFeature()
        } withDependencies: {
            $0.v1CurriculumClient.loadChapter = { _ in chapter }
            $0.v1KnowledgeCatalogClient.loadCatalog = { catalog }
            $0.v1PersonalKnowledgeClient.loadRevisions = { _ in [] }
            $0.v1PersonalKnowledgeClient.loadRelations = { _ in [] }
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

    @Test
    func failedPersonalizationReloadKeepsTheLastSuccessfulSnapshot()
        async throws
    {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageID: LearningPageID = "chapter-02-page-05"
        let snapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: []
        )
        let store = TestStore(
            initialState: V1KnowledgeContextFeature.State(
                chapterID: chapter.id,
                currentPageID: pageID,
                snapshot: snapshot
            )
        ) {
            V1KnowledgeContextFeature()
        } withDependencies: {
            $0.v1CurriculumClient.loadChapter = { _ in chapter }
            $0.v1KnowledgeCatalogClient.loadCatalog = { catalog }
            $0.v1PersonalKnowledgeClient.loadRevisions = { _ in
                throw NSError(
                    domain: "V1KnowledgeContextFeatureTests",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "테스트 개인 지식 조회 실패"
                    ]
                )
            }
            $0.v1PersonalKnowledgeClient.loadRelations = { _ in [] }
        }

        await store.send(.reloadRequested(.personalizationSaved)) {
            $0.isLoading = true
            $0.lastReloadReason = .personalizationSaved
            $0.reloadRequestCount = 1
        }
        await store.receive(.loadResponse(.failed(
            pageID: pageID,
            message: "테스트 개인 지식 조회 실패"
        ))) {
            $0.isLoading = false
            $0.loadErrorMessage = "테스트 개인 지식 조회 실패"
        }

        #expect(store.state.snapshot == snapshot)
    }

    @Test
    func conceptSelectionOpensTheInspectorWithoutReplacingTheSnapshot()
        async throws
    {
        let chapter = try loadChapter()
        let snapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: try loadCatalog(),
            pageID: "chapter-02-page-05",
            revisions: []
        )
        let item = try #require(snapshot.directConcepts.first {
            $0.id == "concept-constants-variables"
        })
        let expectedInspector = V1ConceptInspectorFeature.State(
            sourcePageTitle: snapshot.pageTitle,
            item: item,
            availableConcepts: snapshot.availableConcepts,
            baseRelations: snapshot.baseRelations,
            personalRelations: snapshot.personalRelations,
            relationCreationContract: snapshot.relationCreationContract
        )
        let store = TestStore(
            initialState: V1KnowledgeContextFeature.State(
                chapterID: chapter.id,
                currentPageID: snapshot.pageID,
                snapshot: snapshot
            )
        ) {
            V1KnowledgeContextFeature()
        }

        await store.send(.conceptSelected(item.id)) {
            $0.inspector = expectedInspector
        }
        #expect(store.state.snapshot == snapshot)

        await store.send(.inspector(.cancelButtonTapped))
        await store.receive(.inspector(.delegate(.cancelled))) {
            $0.inspector = nil
        }
    }

    @Test
    func savedInspectorClosesAndDelegatesARepositoryRefresh() async throws {
        let chapter = try loadChapter()
        let snapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: try loadCatalog(),
            pageID: "chapter-02-page-05",
            revisions: []
        )
        let item = try #require(snapshot.directConcepts.first {
            $0.id == "concept-constants-variables"
        })
        let revision = PersonalConceptRevision(
            id: "revision-saved",
            conceptID: item.id,
            personalTitle: "변경 책임",
            explanation: "값 변경은 현재 범위의 책임으로 판단한다.",
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: try #require(
                item.revisionEvidenceActivityID
            ),
            createdAt: .distantPast
        )
        var initialState = V1KnowledgeContextFeature.State(
            chapterID: chapter.id,
            currentPageID: snapshot.pageID,
            snapshot: snapshot
        )
        initialState.inspector = V1ConceptInspectorFeature.State(
            sourcePageTitle: snapshot.pageTitle,
            item: item
        )
        let store = TestStore(initialState: initialState) {
            V1KnowledgeContextFeature()
        }

        await store.send(.inspector(.delegate(.saved(revision)))) {
            $0.inspector = nil
        }
        await store.receive(.personalizationSaved(candidateID: nil))
        await store.receive(.delegate(.personalizationSaved(
            candidateID: nil
        )))
    }

    @Test
    func pageRelationDraftOpensTheInspectorWithItsSelectionAndEvidence()
        async throws
    {
        let chapter = try loadChapter()
        let snapshot = try V1KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: try loadCatalog(),
            pageID: "chapter-02-page-07",
            revisions: []
        )
        let request = V1PersonalRelationDraftRequest(
            sourceConceptID: "concept-related-value-grouping",
            targetConceptID: "concept-type-modeling",
            statement: "값 묶기의 경계는 타입 책임으로 이어진다.",
            reason: "관련 값을 구조로 보존하기 때문이다.",
            evidenceActivityID: "activity-page07-role-sorting"
        )
        let item = try #require(snapshot.directConcepts.first {
            $0.id == request.sourceConceptID
        })
        let relationCreationContract = try #require(
            snapshot.relationCreationContract
        )
        var expectedInspector = V1ConceptInspectorFeature.State(
            sourcePageTitle: snapshot.pageTitle,
            item: item,
            availableConcepts: snapshot.availableConcepts,
            baseRelations: snapshot.baseRelations,
            personalRelations: snapshot.personalRelations,
            relationCreationContract: relationCreationContract
        )
        expectedInspector.relationEditor = V1PersonalRelationEditorFeature.State(
            request: request,
            contract: relationCreationContract,
            availableConcepts: snapshot.availableConcepts
        )
        let store = TestStore(
            initialState: V1KnowledgeContextFeature.State(
                chapterID: chapter.id,
                currentPageID: snapshot.pageID,
                snapshot: snapshot
            )
        ) {
            V1KnowledgeContextFeature()
        }

        await store.send(.relationDraftRequested(request)) {
            $0.inspector = expectedInspector
        }
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
