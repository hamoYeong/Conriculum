struct KnowledgeConcept: Codable, Equatable, Sendable {
    let id: KnowledgeConceptID
    let title: String
    let definition: String
    let essentialQuestion: String
    let judgmentQuestions: [String]
    let examples: [String]
    let misconceptions: [String]
}

struct KnowledgeRelation: Codable, Equatable, Sendable {
    let id: KnowledgeRelationID
    let sourceConceptID: KnowledgeConceptID
    let targetConceptID: KnowledgeConceptID
    let kind: KnowledgeRelationKind
    let summary: String
}

enum KnowledgeRelationKind: String, Codable, CaseIterable, Hashable, Sendable {
    case prerequisite
    case related
    case contrastsWith
    case refines
    case appliesTo
    case leadsTo
}

enum KnowledgeLinkRole: String, Codable, CaseIterable, Hashable, Sendable {
    case primary
    case supporting
    case prerequisite
    case enrichment
}
