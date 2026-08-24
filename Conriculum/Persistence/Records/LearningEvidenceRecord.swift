import Foundation
import SwiftData

@Model
final class LearningEvidenceRecord {
    #Index<LearningEvidenceRecord>(
        [\.profileID, \.pageID],
        [\.profileID, \.activityID]
    )

    @Attribute(.unique) var id: String
    var profileID: String
    var kindRawValue: String
    var pageID: String
    var activityID: String?
    var responseID: String?
    var note: String?
    var recordedAt: Date

    init(
        id: String,
        profileID: String,
        kindRawValue: String,
        pageID: String,
        activityID: String?,
        responseID: String?,
        note: String?,
        recordedAt: Date
    ) {
        self.id = id
        self.profileID = profileID
        self.kindRawValue = kindRawValue
        self.pageID = pageID
        self.activityID = activityID
        self.responseID = responseID
        self.note = note
        self.recordedAt = recordedAt
    }
}
