import Foundation

extension CourseProgressRecord {
    convenience init(
        lastVisitedPageID: String?,
        updatedAt: Date
    ) throws {
        if let lastVisitedPageID {
            try PersistenceMappingSupport.validateIdentifier(
                lastVisitedPageID,
                record: Self.recordName,
                fieldPath: "lastVisitedPageID"
            )
        }
        self.init(
            id: Self.storageID,
            lastVisitedPageID: lastVisitedPageID,
            updatedAt: updatedAt
        )
    }

    func validate() throws {
        guard id == Self.storageID else {
            throw PersistenceMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "does not match the course progress identity"
            )
        }
        if let lastVisitedPageID {
            try PersistenceMappingSupport.validateIdentifier(
                lastVisitedPageID,
                record: Self.recordName,
                fieldPath: "lastVisitedPageID"
            )
        }
    }

    func update(lastVisitedPageID: String?, updatedAt: Date) throws {
        if let lastVisitedPageID {
            try PersistenceMappingSupport.validateIdentifier(
                lastVisitedPageID,
                record: Self.recordName,
                fieldPath: "lastVisitedPageID"
            )
        }
        self.lastVisitedPageID = lastVisitedPageID
        self.updatedAt = updatedAt
    }

    static let storageID = "course-progress"

    static let recordName = "CourseProgressRecord"
}
