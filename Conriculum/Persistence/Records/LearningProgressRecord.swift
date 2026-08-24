import Foundation
import SwiftData

@Model
final class LearningProgressRecord {
    #Unique<LearningProgressRecord>([\.profileID, \.chapterID])
    #Index<LearningProgressRecord>(
        [\.profileID, \.chapterID],
        [\.profileID, \.updatedAt]
    )

    @Attribute(.unique) var id: String
    var profileID: String
    var chapterID: String
    var currentPageID: String
    var completedPageIDs: [String]
    var updatedAt: Date

    init(
        id: String,
        profileID: String,
        chapterID: String,
        currentPageID: String,
        completedPageIDs: [String],
        updatedAt: Date
    ) {
        self.id = id
        self.profileID = profileID
        self.chapterID = chapterID
        self.currentPageID = currentPageID
        self.completedPageIDs = completedPageIDs
        self.updatedAt = updatedAt
    }
}
