// MARK: - 모든 학습자에게 공통인 지식 그래프

/// 지식 체계의 한 분류와 그 안에 포함되는 공용 Concept의 순서를 보존한다.
struct KnowledgeCollection: Codable, Equatable, Sendable {
    let id: KnowledgeCollectionID
    let order: Int
    let title: String
    let summary: String
    let systemImage: String
    let conceptIDs: [KnowledgeConceptID]
}

/// 공용 기본 지식. 정의뿐 아니라 질문·예시·오개념까지 판단 재료로 보존한다.
struct KnowledgeConcept: Codable, Equatable, Sendable {
    let id: KnowledgeConceptID
    let title: String
    let definition: String
    let essentialQuestion: String
    let judgmentQuestions: [String]
    let examples: [String]
    let misconceptions: [String]
    /// 이 개념을 직접 사용하거나 완료 뒤 연결해서 볼 수 있는 학습 페이지.
    /// 링크 자체는 학습 노출이나 개인 지식 상태를 만들지 않는다.
    var revisitPages: [KnowledgeLearningReference]? = nil
}

/// 지식 노트의 단일 `다시 보기` 섹션을 앱에서도 이동 가능한 링크로 보존한다.
struct KnowledgeLearningReference: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Equatable, Sendable {
        case direct
        case nearby
    }

    var id: LearningPageID { pageID }
    let chapterID: ChapterID
    let chapterOrder: Int
    let chapterTitle: String
    let pageID: LearningPageID
    let pageOrder: Int?
    let pageTitle: String
    let kind: Kind
    let connection: String
}

/// 두 `KnowledgeConcept` 사이의 방향 있는 지식 그래프 edge.
struct KnowledgeRelation: Codable, Equatable, Sendable {
    let id: KnowledgeRelationID
    let sourceConceptID: KnowledgeConceptID
    let targetConceptID: KnowledgeConceptID
    let kind: KnowledgeRelationKind
    let summary: String
}

/// Concept → Concept이 어떤 의미로 연결되는지를 분류한다.
enum KnowledgeRelationKind: String, Codable, CaseIterable, Hashable, Sendable {
    case prerequisite
    case related
    case contrastsWith
    case refines
    case appliesTo
    case leadsTo
}

/// Page → Concept 참조의 목적을 분류한다.
/// Concept끼리의 관계인 `KnowledgeRelationKind`와 책임이 다르다.
enum KnowledgeLinkRole: String, Codable, CaseIterable, Hashable, Sendable {
    case primary
    case supporting
    case prerequisite
    case enrichment
}

// MARK: - 다음 읽기: Domain/Knowledge/PersonalKnowledgeModels.swift
