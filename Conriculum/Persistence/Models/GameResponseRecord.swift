import Foundation
import SwiftData

@Model
final class GameResponseRecord {
    @Attribute(.unique) var id: String
    var contentVersion: String
    var activityID: String
    var selectedOptionIDs: [String]
    var matchesPayload: Data
    var isCorrect: Bool
    var attempts: Int
    var answeredAt: Date

    init(
        id: String,
        contentVersion: String,
        activityID: String,
        selectedOptionIDs: [String],
        matchesPayload: Data,
        isCorrect: Bool,
        attempts: Int,
        answeredAt: Date
    ) {
        self.id = id
        self.contentVersion = contentVersion
        self.activityID = activityID
        self.selectedOptionIDs = selectedOptionIDs
        self.matchesPayload = matchesPayload
        self.isCorrect = isCorrect
        self.attempts = attempts
        self.answeredAt = answeredAt
    }
}
