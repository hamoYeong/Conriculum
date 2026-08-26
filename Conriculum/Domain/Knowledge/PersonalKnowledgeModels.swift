import Foundation

// MARK: - 5. 공용 지식을 덮어쓰지 않는 사용자 지식 overlay

/// 공용 `KnowledgeConcept`를 수정하지 않고 별도로 쌓는 사용자의 해석 revision.
/// 이전 revision과 근거 activity를 연결해 변화 이력을 보존한다.
struct PersonalConceptRevision: Codable, Equatable, Sendable {
    let id: PersonalConceptRevisionID
    let conceptID: KnowledgeConceptID
    let personalTitle: String?
    let explanation: String
    let examples: [PersonalExample]
    let previousRevisionID: PersonalConceptRevisionID?
    let evidenceActivityID: LearningActivityID
    let createdAt: Date
}

/// 개인 revision에 포함되는 사용자 자신의 사례와 선택적 맥락.
struct PersonalExample: Codable, Equatable, Sendable {
    let id: PersonalExampleID
    let text: String
    let context: String?
}

/// 사용자가 두 공용 Concept 사이에 직접 만든 연결.
/// 기본 관계와 달리 사용자의 문장·이유·학습 근거를 함께 보존한다.
struct PersonalKnowledgeRelation: Codable, Equatable, Sendable {
    let id: PersonalKnowledgeRelationID
    let sourceConceptID: KnowledgeConceptID
    let targetConceptID: KnowledgeConceptID
    let statement: String
    let reason: String
    let evidenceActivityID: LearningActivityID
    let createdAt: Date
}

/// 활동 결과를 곧바로 개인 지식으로 확정하지 않고 검토 가능한 초안으로 두는 중간 Domain.
struct KnowledgePersonalizationCandidate: Codable, Equatable, Sendable {
    /// 후보가 개념 표현 수정인지, 개념 간 새 연결인지 구분한다.
    enum Kind: String, Codable, Equatable, Sendable {
        case conceptRevision
        case knowledgeRelation
    }

    let id: KnowledgePersonalizationCandidateID
    let kind: Kind
    let conceptIDs: [KnowledgeConceptID]
    let draft: String
    let evidenceActivityID: LearningActivityID
    let createdAt: Date
}

// MARK: - 다음 읽기: Domain/LearningRecords/LearningRecordModels.swift
