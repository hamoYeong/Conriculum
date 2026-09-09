import Foundation
import SwiftData

@Model
final class PageProgressRecord {
    @Attribute(.unique) var id: String
    var pageID: String
    var isCompleted: Bool
    var supportLevelRawValue: String?
    var completedAt: Date?
    var updatedAt: Date

    init(
        id: String,
        pageID: String,
        isCompleted: Bool,
        supportLevelRawValue: String?,
        completedAt: Date?,
        updatedAt: Date
    ) {
        self.id = id
        self.pageID = pageID
        self.isCompleted = isCompleted
        self.supportLevelRawValue = supportLevelRawValue
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }
}
