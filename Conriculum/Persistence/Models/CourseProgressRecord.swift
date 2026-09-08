import Foundation
import SwiftData

@Model
final class CourseProgressRecord {
    @Attribute(.unique) var id: String
    var contentVersion: String
    var lastVisitedPageID: String?
    var updatedAt: Date

    init(
        id: String,
        contentVersion: String,
        lastVisitedPageID: String?,
        updatedAt: Date
    ) {
        self.id = id
        self.contentVersion = contentVersion
        self.lastVisitedPageID = lastVisitedPageID
        self.updatedAt = updatedAt
    }
}
