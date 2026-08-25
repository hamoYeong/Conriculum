import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct PersonalRelationEditorFeatureTests {
    private let timestamp = Date(timeIntervalSince1970: 1_725_868_800)
    private let relationUUID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000083"
    )!

    @Test
    func createSavesAndReadsBackTheRelationWithItsEvidence() async {
        let repository = PersonalRelationRepositorySpy()
        let store = TestStore(initialState: newRelationState()) {
            PersonalRelationEditorFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.uuid = .constant(relationUUID)
            $0.personalKnowledgeClient.saveRelation = { relation in
                await repository.save(relation)
            }
            $0.personalKnowledgeClient.loadRelations = { _ in
                await repository.load()
            }
        }
        let expectedRelation = PersonalKnowledgeRelation(
            id: PersonalKnowledgeRelationID(
                rawValue: relationUUID.uuidString.lowercased()
            ),
            sourceConceptID: "concept-related-value-grouping",
            targetConceptID: "concept-type-modeling",
            statement: "값 묶기의 경계는 타입이 맡을 책임의 후보가 된다.",
            reason: "함께 변하는 값의 책임을 구조로 보존할 수 있기 때문이다.",
            evidenceActivityID: "activity-page07-role-sorting",
            createdAt: timestamp
        )

        await store.send(.statementChanged(
            "  값 묶기의 경계는 타입이 맡을 책임의 후보가 된다.  "
        )) {
            $0.statement =
                "  값 묶기의 경계는 타입이 맡을 책임의 후보가 된다.  "
        }
        await store.send(.reasonChanged(
            "  함께 변하는 값의 책임을 구조로 보존할 수 있기 때문이다.  "
        )) {
            $0.reason =
                "  함께 변하는 값의 책임을 구조로 보존할 수 있기 때문이다.  "
        }
        await store.send(.saveButtonTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.saved(expectedRelation))) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved(expectedRelation)))

        let saved = await repository.savedRelations()
        let loads = await repository.loadCallCount()
        #expect(saved == [expectedRelation])
        #expect(loads == 1)
    }

    @Test
    func updatePreservesIdentityAndEvidenceWhileReplacingTheStoredFields()
        async
    {
        let original = existingRelation()
        let repository = PersonalRelationRepositorySpy(relations: [original])
        let store = TestStore(
            initialState: PersonalRelationEditorFeature.State(
                editing: original,
                availableConcepts: concepts
            )
        ) {
            PersonalRelationEditorFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.personalKnowledgeClient.saveRelation = { relation in
                await repository.save(relation)
            }
            $0.personalKnowledgeClient.loadRelations = { _ in
                await repository.load()
            }
        }
        let expectedRelation = PersonalKnowledgeRelation(
            id: original.id,
            sourceConceptID: original.sourceConceptID,
            targetConceptID: original.targetConceptID,
            statement: "값 묶기의 경계는 타입 책임을 구체화한다.",
            reason: "두 개념을 함께 써 보며 책임의 경계를 확인했다.",
            evidenceActivityID: original.evidenceActivityID,
            createdAt: timestamp
        )

        await store.send(.statementChanged(expectedRelation.statement)) {
            $0.statement = expectedRelation.statement
        }
        await store.send(.reasonChanged(expectedRelation.reason)) {
            $0.reason = expectedRelation.reason
        }
        await store.send(.saveButtonTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.saved(expectedRelation))) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved(expectedRelation)))

        let saved = await repository.savedRelations()
        #expect(saved == [expectedRelation])
        #expect(saved.first?.id == original.id)
        #expect(
            saved.first?.evidenceActivityID == original.evidenceActivityID
        )
    }

    @Test
    func failureKeepsTheStoredRelationAndEveryDraftFieldForRetry() async {
        let original = existingRelation()
        let repository = PersonalRelationRepositorySpy(relations: [original])
        let store = TestStore(
            initialState: PersonalRelationEditorFeature.State(
                editing: original,
                availableConcepts: concepts
            )
        ) {
            PersonalRelationEditorFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.personalKnowledgeClient.saveRelation = { _ in
                throw NSError(
                    domain: "PersonalRelationEditorFeatureTests",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "테스트 관계 저장 실패"
                    ]
                )
            }
            $0.personalKnowledgeClient.loadRelations = { _ in
                await repository.load()
            }
        }

        await store.send(.statementChanged("재시도할 관계 문장")) {
            $0.statement = "재시도할 관계 문장"
        }
        await store.send(.reasonChanged("재시도할 관계 이유")) {
            $0.reason = "재시도할 관계 이유"
        }
        await store.send(.saveButtonTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.failed("테스트 관계 저장 실패"))) {
            $0.isSaving = false
            $0.persistenceErrorMessage = "테스트 관계 저장 실패"
        }

        #expect(store.state.originalRelation == original)
        #expect(store.state.statement == "재시도할 관계 문장")
        #expect(store.state.reason == "재시도할 관계 이유")
        let loads = await repository.loadCallCount()
        #expect(loads == 0)
    }

    @Test
    func sourceSelectionMovesAnInvalidSameTargetAndValidationIsExplicit()
        async
    {
        let store = TestStore(initialState: newRelationState()) {
            PersonalRelationEditorFeature()
        }

        await store.send(.sourceConceptChanged("concept-type-modeling")) {
            $0.sourceConceptID = "concept-type-modeling"
            $0.targetConceptID = "concept-identifier-naming"
        }
        await store.send(.reasonChanged(""))
        await store.send(.saveButtonTapped) {
            $0.validationMessage = PersonalRelationValidationError
                .missingReason.errorDescription
        }
    }

    private func newRelationState() -> PersonalRelationEditorFeature.State {
        PersonalRelationEditorFeature.State(
            request: PersonalRelationDraftRequest(
                sourceConceptID: "concept-related-value-grouping",
                targetConceptID: "concept-type-modeling",
                statement: "값 묶기의 경계는 타입이 맡을 책임의 후보가 된다.",
                reason: "",
                evidenceActivityID: "activity-page07-role-sorting"
            ),
            contract: KnowledgeContextSnapshot.RelationCreationContract(
                sourceConceptIDs: [
                    "concept-related-value-grouping",
                    "concept-type-modeling",
                ],
                targetConceptIDs: [
                    "concept-type-modeling",
                    "concept-identifier-naming",
                ],
                draftStatement: "값 묶기의 경계는 타입이 맡을 책임의 후보가 된다.",
                reasonPrompt: "이 관계를 만든 이유",
                evidenceActivityID: "activity-page07-role-sorting"
            ),
            availableConcepts: concepts
        )
    }

    private func existingRelation() -> PersonalKnowledgeRelation {
        PersonalKnowledgeRelation(
            id: "personal-relation-existing",
            sourceConceptID: "concept-related-value-grouping",
            targetConceptID: "concept-type-modeling",
            statement: "값 묶기의 경계는 타입 책임으로 이어진다.",
            reason: "관련 값을 구조로 보존하기 때문이다.",
            evidenceActivityID: "activity-page07-role-sorting",
            createdAt: .distantPast
        )
    }

    private var concepts: [KnowledgeConcept] {
        [
            concept(
                id: "concept-related-value-grouping",
                title: "관련 값 묶기"
            ),
            concept(id: "concept-type-modeling", title: "타입 모델링"),
            concept(id: "concept-identifier-naming", title: "식별자 이름 짓기"),
        ]
    }

    private func concept(
        id: KnowledgeConceptID,
        title: String
    ) -> KnowledgeConcept {
        KnowledgeConcept(
            id: id,
            title: title,
            definition: "테스트 정의",
            essentialQuestion: "테스트 질문",
            judgmentQuestions: [],
            examples: [],
            misconceptions: []
        )
    }
}

private actor PersonalRelationRepositorySpy {
    private var relations: [PersonalKnowledgeRelation]
    private var saves: [PersonalKnowledgeRelation] = []
    private var loads = 0

    init(relations: [PersonalKnowledgeRelation] = []) {
        self.relations = relations
    }

    func save(_ relation: PersonalKnowledgeRelation) {
        saves.append(relation)
        relations = [relation]
    }

    func load() -> [PersonalKnowledgeRelation] {
        loads += 1
        return relations
    }

    func savedRelations() -> [PersonalKnowledgeRelation] {
        saves
    }

    func loadCallCount() -> Int {
        loads
    }
}
