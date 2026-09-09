import Foundation
import SwiftData

@Model
final class PersonalConceptRevisionRecord {
    #Index<PersonalConceptRevisionRecord>(
        [\.profileID, \.conceptID],
        [\.profileID, \.createdAt]
    )

    @Attribute(.unique) var id: String
    var profileID: String
    var conceptID: String
    var personalTitle: String?
    var explanation: String
    var examplesPayload: Data
    var previousRevisionID: String?
    var evidenceActivityID: String
    var createdAt: Date

    init(
        id: String,
        profileID: String,
        conceptID: String,
        personalTitle: String?,
        explanation: String,
        examplesPayload: Data,
        previousRevisionID: String?,
        evidenceActivityID: String,
        createdAt: Date
    ) {
        self.id = id
        self.profileID = profileID
        self.conceptID = conceptID
        self.personalTitle = personalTitle
        self.explanation = explanation
        self.examplesPayload = examplesPayload
        self.previousRevisionID = previousRevisionID
        self.evidenceActivityID = evidenceActivityID
        self.createdAt = createdAt
    }
}
