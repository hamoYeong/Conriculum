protocol StableIDTag: Sendable {}

struct StableID<Tag: StableIDTag>: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension StableID: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

extension StableID: CustomStringConvertible {
    var description: String { rawValue }
}

enum LearningPathIDTag: StableIDTag {}
enum LocalProfileIDTag: StableIDTag {}
enum StageIDTag: StableIDTag {}
enum ChapterIDTag: StableIDTag {}
enum LearningPageIDTag: StableIDTag {}
enum LearningSectionIDTag: StableIDTag {}
enum LearningActivityIDTag: StableIDTag {}
enum KnowledgeConceptIDTag: StableIDTag {}
enum KnowledgeRelationIDTag: StableIDTag {}
enum PersonalConceptRevisionIDTag: StableIDTag {}
enum PersonalKnowledgeRelationIDTag: StableIDTag {}
enum PersonalExampleIDTag: StableIDTag {}
enum KnowledgePersonalizationCandidateIDTag: StableIDTag {}
enum ActivityResponseIDTag: StableIDTag {}
enum LearningEvidenceIDTag: StableIDTag {}

typealias LearningPathID = StableID<LearningPathIDTag>
typealias LocalProfileID = StableID<LocalProfileIDTag>
typealias StageID = StableID<StageIDTag>
typealias ChapterID = StableID<ChapterIDTag>
typealias LearningPageID = StableID<LearningPageIDTag>
typealias LearningSectionID = StableID<LearningSectionIDTag>
typealias LearningActivityID = StableID<LearningActivityIDTag>
typealias KnowledgeConceptID = StableID<KnowledgeConceptIDTag>
typealias KnowledgeRelationID = StableID<KnowledgeRelationIDTag>
typealias PersonalConceptRevisionID = StableID<PersonalConceptRevisionIDTag>
typealias PersonalKnowledgeRelationID = StableID<PersonalKnowledgeRelationIDTag>
typealias PersonalExampleID = StableID<PersonalExampleIDTag>
typealias KnowledgePersonalizationCandidateID = StableID<KnowledgePersonalizationCandidateIDTag>
typealias ActivityResponseID = StableID<ActivityResponseIDTag>
typealias LearningEvidenceID = StableID<LearningEvidenceIDTag>
