import Foundation
import SwiftData

@Model
final class CourseProgressRecord {
    @Attribute(.unique) var id: String
    var lastVisitedPageID: String?
    var updatedAt: Date

    init(
        id: String,
        lastVisitedPageID: String?,
        updatedAt: Date
    ) {
        self.id = id
        self.lastVisitedPageID = lastVisitedPageID
        self.updatedAt = updatedAt
    }
}
