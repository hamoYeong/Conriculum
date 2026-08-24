import Foundation
import Testing

@testable import Conriculum

struct KnowledgeAndLearningRecordTests {
    @Test
    func personalRevisionDoesNotReplaceBaseConcept() {
        let concept = KnowledgeConcept(
            id: "concept-value",
            title: "값",
            definition: "프로그램이 다루는 구체적인 정보다.",
            essentialQuestion: "지금 프로그램이 직접 다룰 대상은 무엇인가?",
            judgmentQuestions: ["하나의 구체적인 정보인가?"],
            examples: ["20_000"],
            misconceptions: ["숫자만 값이라고 생각한다."]
        )
        let revision = PersonalConceptRevision(
            id: "revision-value-01",
            conceptID: concept.id,
            personalTitle: "한 번에 다룰 정보",
            explanation: "이 사례에서 하나로 정해진 정보다.",
            examples: [
                PersonalExample(id: "example-value-01", text: "이번 주문의 수량 2", context: "주문")
            ],
            previousRevisionID: nil,
            evidenceActivityID: "activity-page-01-card-sorting",
            createdAt: Date(timeIntervalSince1970: 1)
        )

        #expect(concept.title == "값")
        #expect(concept.definition == "프로그램이 다루는 구체적인 정보다.")
        #expect(revision.conceptID == concept.id)
        #expect(revision.explanation != concept.definition)
    }

    @Test
    func personalRelationKeepsReasonAndEvidenceActivity() {
        let relation = PersonalKnowledgeRelation(
            id: "personal-relation-grouping-modeling",
            sourceConceptID: "concept-related-value-grouping",
            targetConceptID: "concept-type-modeling",
            statement: "값 묶음의 경계는 사용자 정의 타입 책임의 후보가 된다.",
            reason: "함께 쓰이는 관계를 타입 구조로 보존할 수 있기 때문이다.",
            evidenceActivityID: "activity-page-07-create-relation",
            createdAt: Date(timeIntervalSince1970: 2)
        )

        #expect(relation.reason.isEmpty == false)
        #expect(relation.evidenceActivityID == "activity-page-07-create-relation")
    }

    @Test
    func linkRolesAndEvidenceKindsMatchTheDomainContract() {
        #expect(Set(KnowledgeLinkRole.allCases) == [
            .primary, .supporting, .prerequisite, .enrichment,
        ])
        #expect(Set(LearningEvidenceKind.allCases) == [
            .viewed,
            .activityAttempt,
            .assistedSuccess,
            .independentSuccess,
            .reasoningExplanation,
            .conceptLink,
        ])
    }

    @Test
    func knowledgeAndLearningRecordValuesAreSendable() {
        let progress = LearningProgress(
            chapterID: "chapter-02",
            currentPageID: "chapter-02-page-01",
            completedPageIDs: [],
            updatedAt: Date(timeIntervalSince1970: 3)
        )

        assertKnowledgeSendable(progress)
        assertKnowledgeSendable(KnowledgeLinkRole.primary)
        assertKnowledgeSendable(LearningEvidenceKind.reasoningExplanation)
    }
}

private func assertKnowledgeSendable<Value: Sendable>(_ value: Value) {}
