import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct CurrentKnowledgeSystemFeatureTests {
    @Test
    func loadUsesCatalogAndProgress() async throws {
        let catalog = try BundledContentStore().loadKnowledgeCatalog()
        let references = catalog.concepts.flatMap { $0.revisitPages ?? [] }
        let learnedPageID = try #require(references.first).pageID.rawValue
        let progress = CourseProgress(
            lastVisitedPageID: learnedPageID,
            completedPageIDs: [learnedPageID]
        )
        let learnedConceptIDs = Set(catalog.concepts.compactMap { concept in
            concept.revisitPages?.contains {
                $0.pageID.rawValue == learnedPageID
            } == true ? concept.id : nil
        })
        let expected = KnowledgeSystemSnapshotComposer().compose(
            catalog: catalog,
            revisions: [],
            personalRelations: [],
            learnedConceptIDs: learnedConceptIDs
        )
        let store = TestStore(
            initialState: KnowledgeSystemFeature.State()
        ) {
            KnowledgeSystemFeature()
        } withDependencies: {
            $0.contentClient.loadKnowledgeCatalog = { catalog }
            $0.progressClient.load = { progress }
        }

        await store.send(.task)
        await store.receive(.retryButtonTapped) {
            $0.isLoading = true
            $0.loadErrorMessage = nil
        }
        await store.receive(.loadResponse(.loaded(expected))) {
            $0.isLoading = false
            $0.snapshot = expected
        }

        #expect(store.state.snapshot?.concepts.contains {
            $0.learningStatus == .learned
        } == true)
    }

    @Test
    func currentRevisitRoutesToTheCurrentLearningPage() async throws {
        let catalog = try BundledContentStore().loadKnowledgeCatalog()
        let references = catalog.concepts.flatMap { $0.revisitPages ?? [] }
        let reference = try #require(references.first)
        let store = TestStore(
            initialState: KnowledgeSystemFeature.State()
        ) {
            KnowledgeSystemFeature()
        }

        await store.send(.learningPageTapped(reference))
        await store.receive(.delegate(.learningRequested(
            reference.pageID.rawValue
        )))
    }

    @Test
    func currentCatalogSupportsCollectionSearchAndConceptComparison() async throws {
        let catalog = try BundledContentStore().loadKnowledgeCatalog()
        let learnedConceptIDs = Set(catalog.concepts.map(\.id))
        let snapshot = KnowledgeSystemSnapshotComposer().compose(
            catalog: catalog,
            revisions: [],
            personalRelations: [],
            learnedConceptIDs: learnedConceptIDs
        )
        let collection = try #require(snapshot.collections.first)
        let collectionConcepts = snapshot.concepts.filter {
            $0.collectionID == collection.id
        }
        let first = try #require(collectionConcepts.first)
        let second = try #require(collectionConcepts.dropFirst().first)
        let third = try #require(collectionConcepts.dropFirst(2).first)
        let store = TestStore(
            initialState: KnowledgeSystemFeature.State(snapshot: snapshot)
        ) {
            KnowledgeSystemFeature()
        }

        await store.send(.collectionSelected(collection.id)) {
            $0.selectedCollectionID = collection.id
        }
        #expect(store.state.visibleConcepts.allSatisfy {
            $0.collectionID == collection.id
        })

        await store.send(.searchQueryChanged(first.concept.title)) {
            $0.searchQuery = first.concept.title
        }
        #expect(store.state.visibleConcepts.contains { $0.id == first.id })

        await store.send(.conceptSelected(first.id)) {
            $0.selectedConceptIDs = [first.id]
        }
        await store.send(.compareConceptRequested(second.id)) {
            $0.selectedConceptIDs = [first.id, second.id]
        }
        await store.send(.compareConceptRequested(third.id)) {
            $0.selectedConceptIDs = [first.id, third.id]
        }
        await store.send(.conceptClosed(first.id)) {
            $0.selectedConceptIDs = [third.id]
        }
        await store.send(.selectionCleared) {
            $0.selectedConceptIDs = []
        }
    }

    @Test
    func currentReloadFailurePreservesLastSuccessfulSnapshot() async throws {
        let catalog = try BundledContentStore().loadKnowledgeCatalog()
        let snapshot = KnowledgeSystemSnapshotComposer().compose(
            catalog: catalog,
            revisions: [],
            personalRelations: []
        )
        let store = TestStore(
            initialState: KnowledgeSystemFeature.State(snapshot: snapshot)
        ) {
            KnowledgeSystemFeature()
        } withDependencies: {
            $0.contentClient.loadKnowledgeCatalog = {
                throw CurrentKnowledgeTestError()
            }
            $0.progressClient.load = { .empty }
        }

        await store.send(.retryButtonTapped) {
            $0.isLoading = true
        }
        await store.receive(.loadResponse(.failed(
            message: "현재 지식 체계 조회 실패"
        ))) {
            $0.isLoading = false
            $0.loadErrorMessage = "현재 지식 체계 조회 실패"
        }
        #expect(store.state.snapshot == snapshot)
    }
}

private struct CurrentKnowledgeTestError: LocalizedError {
    var errorDescription: String? { "현재 지식 체계 조회 실패" }
}
