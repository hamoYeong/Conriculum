import Foundation
import SwiftData

@Model
final class PageProgressRecord {
    @Attribute(.unique) var id: String
    var contentVersion: String
    var pageID: String
    var isCompleted: Bool
    var supportLevelRawValue: String?
    var completedAt: Date?
    var updatedAt: Date

    init(
        id: String,
        contentVersion: String,
        pageID: String,
        isCompleted: Bool,
        supportLevelRawValue: String?,
        completedAt: Date?,
        updatedAt: Date
    ) {
        self.id = id
        self.contentVersion = contentVersion
        self.pageID = pageID
        self.isCompleted = isCompleted
        self.supportLevelRawValue = supportLevelRawValue
        self.completedAt = completedAt
        self.updatedAt = updatedAt
    }
}
