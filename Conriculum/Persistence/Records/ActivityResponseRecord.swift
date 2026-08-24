import Foundation
import SwiftData

@Model
final class ActivityResponseRecord {
    #Index<ActivityResponseRecord>(
        [\.profileID, \.pageID],
        [\.profileID, \.activityID]
    )

    @Attribute(.unique) var id: String
    var profileID: String
    var activityID: String
    var pageID: String
    var fieldsPayload: Data
    var recordedAt: Date

    init(
        id: String,
        profileID: String,
        activityID: String,
        pageID: String,
        fieldsPayload: Data,
        recordedAt: Date
    ) {
        self.id = id
        self.profileID = profileID
        self.activityID = activityID
        self.pageID = pageID
        self.fieldsPayload = fieldsPayload
        self.recordedAt = recordedAt
    }
}
