import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct KnowledgeSystemFeatureTests {
    @Test
    func loadComposesCatalogAndPersonalKnowledge() async throws {
        let catalog = try loadCatalog()
        let revision = PersonalConceptRevision(
            id: "revision-type",
            conceptID: "concept-type",
            personalTitle: "할 수 있는 일의 약속",
            explanation: "값의 사용 범위를 설명한다.",
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: "activity-type",
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let relation = PersonalKnowledgeRelation(
            id: "relation-value-type",
            sourceConceptID: "concept-value",
            targetConceptID: "concept-type",
            statement: "값과 타입을 함께 본다.",
            reason: "사용 가능한 일을 판단하기 위해서다.",
            evidenceActivityID: "activity-type",
            createdAt: Date(timeIntervalSince1970: 30)
        )
        let expected = KnowledgeSystemSnapshotComposer().compose(
            catalog: catalog,
            revisions: [revision],
            personalRelations: [relation, relation]
        )
        let store = TestStore(
            initialState: KnowledgeSystemFeature.State()
        ) {
            KnowledgeSystemFeature()
        } withDependencies: {
            $0.v1KnowledgeCatalogClient.loadCatalog = { catalog }
            $0.v1LearningRecordClient.loadResponses = { _ in [] }
            $0.v1LearningRecordClient.loadProgress = { _ in nil }
            $0.v1LearningRecordClient.loadEvidence = { _ in [] }
            $0.v1PersonalKnowledgeClient.loadAllRevisions = { [revision] }
            $0.v1PersonalKnowledgeClient.loadAllRelations = {
                [relation, relation]
            }
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
    }

    @Test
    func searchCollectionAndModeShareOneVisibleConceptSet() async throws {
        let snapshot = KnowledgeSystemSnapshotComposer().compose(
            catalog: try loadCatalog(),
            revisions: [],
            personalRelations: []
        )
        let valuesCollectionID: KnowledgeCollectionID =
            "collection-02-values-and-types"
        let store = TestStore(
            initialState: KnowledgeSystemFeature.State(snapshot: snapshot)
        ) {
            KnowledgeSystemFeature()
        }

        #expect(store.state.visibleConcepts.count == snapshot.concepts.count)
        await store.send(.collectionSelected(valuesCollectionID)) {
            $0.selectedCollectionID = valuesCollectionID
        }
        await store.send(.searchQueryChanged("참·거짓")) {
            $0.searchQuery = "참·거짓"
        }
        #expect(
            store.state.visibleConcepts.map(\.id)
                == ["concept-type", "concept-bool"]
        )
        #expect(
            store.state.visibleBaseRelations.map(\.id)
                == ["relation-bool-type"]
        )
        #expect(
            store.state.visibleConcepts.map(\.id)
                == ["concept-type", "concept-bool"]
        )
    }

    @Test
    func selectionKeepsAtMostTwoConceptsAndCanCloseEitherPane()
        async throws
    {
        let snapshot = KnowledgeSystemSnapshotComposer().compose(
            catalog: try loadCatalog(),
            revisions: [],
            personalRelations: [],
            learnedConceptIDs: ["concept-value", "concept-type", "concept-bool"]
        )
        let store = TestStore(
            initialState: KnowledgeSystemFeature.State(snapshot: snapshot)
        ) {
            KnowledgeSystemFeature()
        }

        await store.send(.conceptSelected("concept-value")) {
            $0.selectedConceptIDs = ["concept-value"]
        }
        await store.send(.compareConceptRequested("concept-type")) {
            $0.selectedConceptIDs = ["concept-value", "concept-type"]
        }
        await store.send(.compareConceptRequested("concept-bool")) {
            $0.selectedConceptIDs = ["concept-value", "concept-bool"]
        }
        await store.send(.conceptClosed("concept-value")) {
            $0.selectedConceptIDs = ["concept-bool"]
        }
        await store.send(.selectionCleared) {
            $0.selectedConceptIDs = []
        }
    }

    @Test
    func reloadFailurePreservesLastSuccessfulSnapshot() async throws {
        let snapshot = KnowledgeSystemSnapshotComposer().compose(
            catalog: try loadCatalog(),
            revisions: [],
            personalRelations: []
        )
        let store = TestStore(
            initialState: KnowledgeSystemFeature.State(snapshot: snapshot)
        ) {
            KnowledgeSystemFeature()
        } withDependencies: {
            $0.v1KnowledgeCatalogClient.loadCatalog = {
                throw NSError(
                    domain: "KnowledgeSystemFeatureTests",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "지식 체계 조회 실패"
                    ]
                )
            }
            $0.v1PersonalKnowledgeClient.loadAllRevisions = { [] }
            $0.v1PersonalKnowledgeClient.loadAllRelations = { [] }
        }

        await store.send(.retryButtonTapped) {
            $0.isLoading = true
        }
        await store.receive(.loadResponse(.failed(
            message: "지식 체계 조회 실패"
        ))) {
            $0.isLoading = false
            $0.loadErrorMessage = "지식 체계 조회 실패"
        }
        #expect(store.state.snapshot == snapshot)
    }

    private func loadCatalog() throws -> KnowledgeCatalog {
        try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
    }
}
