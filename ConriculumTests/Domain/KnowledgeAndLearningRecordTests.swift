import Foundation
import Testing

@testable import Conriculum

// MARK: - 7. 공용 지식·개인 지식·학습 기록의 경계 확인

struct KnowledgeAndLearningRecordTests {
    /// Collection이 type-safe ID와 Concept ID 순서를 단일 JSON 값으로 왕복하는지 확인한다.
    @Test
    func knowledgeCollectionRoundTripsAsDomainValue() throws {
        let collection = KnowledgeCollection(
            id: "collection-02-values-and-types",
            order: 2,
            title: "값과 타입",
            summary: "현실의 정보를 Swift 값과 타입으로 표현한다.",
            systemImage: "shippingbox",
            conceptIDs: ["concept-value", "concept-type"]
        )

        let encoded = try JSONEncoder().encode(collection)
        let decoded = try JSONDecoder().decode(KnowledgeCollection.self, from: encoded)

        #expect(decoded == collection)
        #expect(decoded.id.rawValue == "collection-02-values-and-types")
        #expect(decoded.conceptIDs == ["concept-value", "concept-type"])
        assertKnowledgeSendable(decoded)
    }

    /// 개인 revision이 base Concept를 교체하지 않고 ID로 참조하는 overlay인지 확인한다.
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

    /// 개인 지식 관계가 연결 문장뿐 아니라 이유와 근거 Activity도 보존하는지 확인한다.
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

    /// Page → Concept 역할과 학습 증거 종류의 case 집합 자체를 Domain 계약으로 고정한다.
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

    /// 지식과 기록 값도 concurrency 경계를 안전하게 넘는 순수 `Sendable` 값인지 확인한다.
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

// MARK: - 다음 읽기: Conriculum/Content/Schema/LearningSectionContent.swift
