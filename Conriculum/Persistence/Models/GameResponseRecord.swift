import Foundation
import SwiftData

@Model
final class GameResponseRecord {
    @Attribute(.unique) var id: String
    var activityID: String
    var selectedOptionIDs: [String]
    var matchesPayload: Data
    var isCorrect: Bool
    var attempts: Int
    var answeredAt: Date

    init(
        id: String,
        activityID: String,
        selectedOptionIDs: [String],
        matchesPayload: Data,
        isCorrect: Bool,
        attempts: Int,
        answeredAt: Date
    ) {
        self.id = id
        self.activityID = activityID
        self.selectedOptionIDs = selectedOptionIDs
        self.matchesPayload = matchesPayload
        self.isCorrect = isCorrect
        self.attempts = attempts
        self.answeredAt = answeredAt
    }
}
