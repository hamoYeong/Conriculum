import Foundation

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

struct PersonalExample: Codable, Equatable, Sendable {
    let id: PersonalExampleID
    let text: String
    let context: String?
}

struct PersonalKnowledgeRelation: Codable, Equatable, Sendable {
    let id: PersonalKnowledgeRelationID
    let sourceConceptID: KnowledgeConceptID
    let targetConceptID: KnowledgeConceptID
    let statement: String
    let reason: String
    let evidenceActivityID: LearningActivityID
    let createdAt: Date
}

struct KnowledgePersonalizationCandidate: Codable, Equatable, Sendable {
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
