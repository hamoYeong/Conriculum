import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct V1ConceptInspectorFeatureTests {
    private let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
    private let revisionUUID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000081"
    )!

    @Test
    func saveCreatesARevisionAndReadsItBackBeforeDelegating() async {
        let oldRevision = revision(
            id: "revision-old",
            title: "변경 여부",
            explanation: "값이 바뀌는지만 본다."
        )
        let repository = PersonalRevisionRepositorySpy(
            revisions: [oldRevision]
        )
        let store = TestStore(
            initialState: state(revision: oldRevision)
        ) {
            V1ConceptInspectorFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.uuid = .constant(revisionUUID)
            $0.v1PersonalKnowledgeClient.saveRevision = { revision in
                await repository.save(revision)
            }
            $0.v1PersonalKnowledgeClient.loadRevisions = { conceptID in
                await repository.load(conceptID: conceptID)
            }
        }
        let expectedRevision = PersonalConceptRevision(
            id: PersonalConceptRevisionID(
                rawValue: revisionUUID.uuidString.lowercased()
            ),
            conceptID: oldRevision.conceptID,
            personalTitle: "변경 책임 약속",
            explanation: "현재 책임 안에서 새 값을 넣어야 하는지를 판단한다.",
            examples: oldRevision.examples,
            previousRevisionID: oldRevision.id,
            evidenceActivityID: "activity-page05-card-sorting",
            createdAt: timestamp
        )

        await store.send(.personalTitleChanged("  변경 책임 약속  ")) {
            $0.personalTitle = "  변경 책임 약속  "
        }
        await store.send(.explanationChanged(
            "  현재 책임 안에서 새 값을 넣어야 하는지를 판단한다.  "
        )) {
            $0.explanation =
                "  현재 책임 안에서 새 값을 넣어야 하는지를 판단한다.  "
        }
        await store.send(.saveButtonTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.saved(expectedRevision))) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved(expectedRevision)))

        let savedRevisions = await repository.savedRevisions()
        let loadCallCount = await repository.loadCallCount()
        #expect(savedRevisions == [expectedRevision])
        #expect(loadCallCount == 1)
    }

    @Test
    func activityCandidateCallsTheClientOnlyAfterFinalConfirmation() async {
        let review = personalizationReview()
        let repository = PersonalRevisionRepositorySpy()
        let store = TestStore(
            initialState: state(personalizationReview: review)
        ) {
            V1ConceptInspectorFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.uuid = .constant(revisionUUID)
            $0.v1PersonalKnowledgeClient.saveRevision = { revision in
                await repository.save(revision)
            }
            $0.v1PersonalKnowledgeClient.loadRevisions = { conceptID in
                await repository.load(conceptID: conceptID)
            }
        }
        let expectedRevision = PersonalConceptRevision(
            id: PersonalConceptRevisionID(
                rawValue: revisionUUID.uuidString.lowercased()
            ),
            conceptID: review.targetConceptID,
            personalTitle: nil,
            explanation: review.candidate.draft,
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: review.candidate.evidenceActivityID,
            createdAt: timestamp
        )

        let savesBeforeConfirmation = await repository.savedRevisions()
        #expect(savesBeforeConfirmation.isEmpty)
        #expect(store.state.personalizationReview == review)
        #expect(store.state.explanation == review.candidate.draft)
        #expect(
            store.state.evidenceActivityID
                == review.candidate.evidenceActivityID
        )

        await store.send(.saveButtonTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.saved(expectedRevision))) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved(expectedRevision)))

        let savesAfterConfirmation = await repository.savedRevisions()
        #expect(savesAfterConfirmation == [expectedRevision])
    }

    @Test
    func cancelKeepsTheDraftLocalAndDoesNotSave() async {
        let repository = PersonalRevisionRepositorySpy()
        let store = TestStore(initialState: state()) {
            V1ConceptInspectorFeature()
        } withDependencies: {
            $0.v1PersonalKnowledgeClient.saveRevision = { revision in
                await repository.save(revision)
            }
        }

        await store.send(.explanationChanged("아직 저장하지 않을 설명")) {
            $0.explanation = "아직 저장하지 않을 설명"
        }
        await store.send(.cancelButtonTapped)
        await store.receive(.delegate(.cancelled))

        #expect(store.state.explanation == "아직 저장하지 않을 설명")
        let savedRevisions = await repository.savedRevisions()
        #expect(savedRevisions.isEmpty)
    }

    @Test
    func persistenceFailureKeepsEveryDraftFieldForRetry() async {
        let store = TestStore(initialState: state()) {
            V1ConceptInspectorFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.uuid = .constant(revisionUUID)
            $0.v1PersonalKnowledgeClient.saveRevision = { _ in
                throw NSError(
                    domain: "V1ConceptInspectorFeatureTests",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "테스트 Revision 저장 실패"
                    ]
                )
            }
        }

        await store.send(.personalTitleChanged("변경 책임")) {
            $0.personalTitle = "변경 책임"
        }
        await store.send(.explanationChanged("재시도할 나의 설명")) {
            $0.explanation = "재시도할 나의 설명"
        }
        await store.send(.saveButtonTapped) {
            $0.isSaving = true
        }
        await store.receive(.saveResponse(.failed(
            "테스트 Revision 저장 실패"
        ))) {
            $0.isSaving = false
            $0.persistenceErrorMessage = "테스트 Revision 저장 실패"
        }

        #expect(store.state.personalTitle == "변경 책임")
        #expect(store.state.explanation == "재시도할 나의 설명")
    }

    @Test
    func missingEvidenceAndIncompleteDraftReportValidationInPlace() async {
        var initialState = state(evidenceActivityID: nil)
        initialState.explanation = "근거 없이 저장하면 안 되는 설명"
        let store = TestStore(initialState: initialState) {
            V1ConceptInspectorFeature()
        }

        await store.send(.saveButtonTapped) {
            $0.validationMessage = V1ConceptRevisionValidationError
                .missingEvidence.errorDescription
        }
        await store.send(.explanationChanged("")) {
            $0.explanation = ""
            $0.validationMessage = nil
        }

        var evidenceState = state()
        evidenceState.personalTitle = "이름만 바꿈"
        let evidenceStore = TestStore(initialState: evidenceState) {
            V1ConceptInspectorFeature()
        }
        await evidenceStore.send(.saveButtonTapped) {
            $0.validationMessage = V1ConceptRevisionValidationError
                .missingExplanation.errorDescription
        }
    }

    private func state(
        revision: PersonalConceptRevision? = nil,
        evidenceActivityID: LearningActivityID? =
            "activity-page05-card-sorting",
        personalizationReview: V1KnowledgePersonalizationReview? = nil
    ) -> V1ConceptInspectorFeature.State {
        V1ConceptInspectorFeature.State(
            sourcePageTitle: "변경 가능성으로 let과 var 판단하기",
            item: V1KnowledgeContextSnapshot.ConceptItem(
                concept: KnowledgeConcept(
                    id: "concept-constants-variables",
                    title: "상수와 변수",
                    definition: "값 변경 가능성을 선언하는 약속이다.",
                    essentialQuestion: "같은 이름에 새 값을 넣어야 하는가?",
                    judgmentQuestions: [],
                    examples: [],
                    misconceptions: []
                ),
                personalRevision: revision,
                revisionEvidenceActivityID: evidenceActivityID,
                role: .primary,
                usage: "현재 책임의 값 변경 여부를 판단한다.",
                nearbyReason: nil
            ),
            personalizationReview: personalizationReview
        )
    }

    private func personalizationReview() -> V1KnowledgePersonalizationReview {
        V1KnowledgePersonalizationReview(
            candidate: KnowledgePersonalizationCandidate(
                id: "candidate-page05-constants",
                kind: .conceptRevision,
                conceptIDs: [
                    "concept-constants-variables",
                    "concept-problem-boundary",
                ],
                draft: "변경 가능성은 현재 책임의 범위로 판단한다.",
                evidenceActivityID: "activity-page05-card-sorting",
                createdAt: .distantPast
            ),
            targetConceptID: "concept-constants-variables",
            activityID: "activity-page05-promotion",
            confirmationQuestion: "이 설명을 나의 변경 책임 기준으로 남길까?",
            savedFields: ["나의 설명", "근거 활동 ID", "수정 시각"]
        )
    }

    private func revision(
        id: PersonalConceptRevisionID,
        title: String,
        explanation: String
    ) -> PersonalConceptRevision {
        PersonalConceptRevision(
            id: id,
            conceptID: "concept-constants-variables",
            personalTitle: title,
            explanation: explanation,
            examples: [
                PersonalExample(
                    id: "example-old",
                    text: "주문 번호는 바뀌지 않는다.",
                    context: "주문 생성"
                )
            ],
            previousRevisionID: nil,
            evidenceActivityID: "activity-page05-choice",
            createdAt: .distantPast
        )
    }
}

private actor PersonalRevisionRepositorySpy {
    private var revisions: [PersonalConceptRevision]
    private var saves: [PersonalConceptRevision] = []
    private var loads = 0

    init(revisions: [PersonalConceptRevision] = []) {
        self.revisions = revisions
    }

    func save(_ revision: PersonalConceptRevision) {
        saves.append(revision)
        revisions.append(revision)
    }

    func load(
        conceptID _: KnowledgeConceptID
    ) -> [PersonalConceptRevision] {
        loads += 1
        return revisions
    }

    func savedRevisions() -> [PersonalConceptRevision] {
        saves
    }

    func loadCallCount() -> Int {
        loads
    }
}
