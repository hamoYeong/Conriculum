import Foundation

extension CourseProgressRecord {
    convenience init(
        contentVersion: ContentVersion,
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
            id: Self.storageID(contentVersion: contentVersion),
            contentVersion: contentVersion.rawValue,
            lastVisitedPageID: lastVisitedPageID,
            updatedAt: updatedAt
        )
    }

    func validate(contentVersion expectedVersion: ContentVersion) throws {
        guard contentVersion == expectedVersion.rawValue else {
            throw PersistenceMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "contentVersion",
                message: "does not belong to the requested content version"
            )
        }
        guard id == Self.storageID(contentVersion: expectedVersion) else {
            throw PersistenceMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "does not match the content version"
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

    static func storageID(contentVersion: ContentVersion) -> String {
        "course-progress:\(contentVersion.rawValue)"
    }

    static let recordName = "CourseProgressRecord"
}
