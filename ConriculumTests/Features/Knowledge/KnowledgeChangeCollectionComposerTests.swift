import Foundation
import Testing

@testable import Conriculum

struct KnowledgeChangeCollectionComposerTests {
    @Test
    func keepsLatestItemPerIdentityAndSeparatesPendingReviews() {
        let firstDate = Date(timeIntervalSince1970: 1_725_782_400)
        let secondDate = firstDate.addingTimeInterval(60)
        let thirdDate = secondDate.addingTimeInterval(60)
        let oldRevision = revision(
            id: "revision-value-old",
            conceptID: "concept-value",
            explanation: "이전 설명",
            createdAt: firstDate
        )
        let latestRevision = revision(
            id: "revision-value-latest",
            conceptID: "concept-value",
            explanation: "최신 설명",
            createdAt: secondDate
        )
        let oldRelation = relation(
            statement: "이전 연결",
            createdAt: firstDate
        )
        let latestRelation = relation(
            statement: "최신 연결",
            createdAt: thirdDate
        )
        let oldReview = review(
            id: "candidate-old",
            targetConceptID: "concept-type",
            draft: "이전 후보",
            createdAt: firstDate
        )
        let latestReview = review(
            id: "candidate-latest",
            targetConceptID: "concept-type",
            draft: "최신 후보",
            createdAt: secondDate
        )

        let collection = KnowledgeChangeCollectionComposer().compose(
            concepts: concepts,
            revisions: [oldRevision, latestRevision],
            relations: [oldRelation, latestRelation],
            pendingReviews: [oldReview, latestReview]
        )

        #expect(collection.confirmed.count == 2)
        guard case let .relation(relationSummary) = collection.confirmed[0],
              case let .revision(revisionSummary) = collection.confirmed[1]
        else {
            Issue.record("확인된 변화가 최신 수정 시각 순서로 정렬되지 않았다.")
            return
        }
        #expect(relationSummary.statement == latestRelation.statement)
        #expect(revisionSummary.id == latestRevision.id)
        #expect(revisionSummary.explanation == latestRevision.explanation)
        #expect(collection.pending.map(\.id) == [latestReview.id])
        #expect(collection.pending.first?.draft == latestReview.candidate.draft)
    }

    @Test
    func equalTimestampsUseStableIdentifiersForDeterministicOrder() {
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let lowerID = revision(
            id: "revision-a",
            conceptID: "concept-value",
            explanation: "A",
            createdAt: timestamp
        )
        let higherID = revision(
            id: "revision-z",
            conceptID: "concept-type",
            explanation: "Z",
            createdAt: timestamp
        )
        let replacement = revision(
            id: "revision-y",
            conceptID: "concept-type",
            explanation: "Y",
            createdAt: timestamp
        )

        let collection = KnowledgeChangeCollectionComposer().compose(
            concepts: concepts,
            revisions: [replacement, lowerID, higherID],
            relations: [],
            pendingReviews: []
        )

        #expect(collection.confirmed.map(\.id) == [
            "revision-revision-a",
            "revision-revision-z",
        ])
    }

    private var concepts: [KnowledgeConcept] {
        [
            concept(id: "concept-value", title: "값"),
            concept(id: "concept-type", title: "타입"),
        ]
    }

    private func concept(
        id: KnowledgeConceptID,
        title: String
    ) -> KnowledgeConcept {
        KnowledgeConcept(
            id: id,
            title: title,
            definition: "\(title)의 정의",
            essentialQuestion: "\(title)이란?",
            judgmentQuestions: [],
            examples: [],
            misconceptions: []
        )
    }

    private func revision(
        id: PersonalConceptRevisionID,
        conceptID: KnowledgeConceptID,
        explanation: String,
        createdAt: Date
    ) -> PersonalConceptRevision {
        PersonalConceptRevision(
            id: id,
            conceptID: conceptID,
            personalTitle: nil,
            explanation: explanation,
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: "activity-evidence",
            createdAt: createdAt
        )
    }

    private func relation(
        statement: String,
        createdAt: Date
    ) -> PersonalKnowledgeRelation {
        PersonalKnowledgeRelation(
            id: "relation-value-type",
            sourceConceptID: "concept-value",
            targetConceptID: "concept-type",
            statement: statement,
            reason: "타입이 값의 사용을 정하기 때문이다.",
            evidenceActivityID: "activity-evidence",
            createdAt: createdAt
        )
    }

    private func review(
        id: KnowledgePersonalizationCandidateID,
        targetConceptID: KnowledgeConceptID,
        draft: String,
        createdAt: Date
    ) -> KnowledgePersonalizationReview {
        KnowledgePersonalizationReview(
            candidate: KnowledgePersonalizationCandidate(
                id: id,
                kind: .conceptRevision,
                conceptIDs: ["concept-value", "concept-type"],
                draft: draft,
                evidenceActivityID: "activity-evidence",
                createdAt: createdAt
            ),
            targetConceptID: targetConceptID,
            activityID: "activity-promotion",
            confirmationQuestion: "나의 지식으로 반영할까?",
            savedFields: ["나의 설명", "근거 활동 ID"]
        )
    }
}
