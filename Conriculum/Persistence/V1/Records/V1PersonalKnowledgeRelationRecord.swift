import Foundation
import SwiftData

@Model
final class PersonalKnowledgeRelationRecord {
    #Index<PersonalKnowledgeRelationRecord>(
        [\.profileID, \.sourceConceptID],
        [\.profileID, \.targetConceptID],
        [\.profileID, \.createdAt]
    )

    @Attribute(.unique) var id: String
    var profileID: String
    var sourceConceptID: String
    var targetConceptID: String
    var statement: String
    var reason: String
    var evidenceActivityID: String
    var createdAt: Date

    init(
        id: String,
        profileID: String,
        sourceConceptID: String,
        targetConceptID: String,
        statement: String,
        reason: String,
        evidenceActivityID: String,
        createdAt: Date
    ) {
        self.id = id
        self.profileID = profileID
        self.sourceConceptID = sourceConceptID
        self.targetConceptID = targetConceptID
        self.statement = statement
        self.reason = reason
        self.evidenceActivityID = evidenceActivityID
        self.createdAt = createdAt
    }
}
