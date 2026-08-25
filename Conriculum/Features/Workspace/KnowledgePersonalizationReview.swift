import Foundation

struct KnowledgePersonalizationReview: Equatable, Identifiable, Sendable {
    var id: KnowledgePersonalizationCandidateID { candidate.id }

    let candidate: KnowledgePersonalizationCandidate
    let targetConceptID: KnowledgeConceptID
    let activityID: LearningActivityID
    let confirmationQuestion: String
    let savedFields: [String]
}
