import Foundation

extension PageProgressRecord {
    convenience init(
        contentVersion: ContentVersion,
        pageID: String,
        isCompleted: Bool,
        supportLevel: LearningSupportLevel?,
        timestamp: Date
    ) throws {
        try Self.validate(pageID: pageID)
        self.init(
            id: Self.storageID(contentVersion: contentVersion, pageID: pageID),
            contentVersion: contentVersion.rawValue,
            pageID: pageID,
            isCompleted: isCompleted,
            supportLevelRawValue: supportLevel?.rawValue,
            completedAt: isCompleted ? timestamp : nil,
            updatedAt: timestamp
        )
    }

    func values(contentVersion expectedVersion: ContentVersion) throws -> (
        pageID: String,
        isCompleted: Bool,
        supportLevel: LearningSupportLevel?
    ) {
        guard contentVersion == expectedVersion.rawValue else {
            throw PersistenceMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "contentVersion",
                message: "does not belong to the requested content version"
            )
        }
        try Self.validate(pageID: pageID)
        guard id == Self.storageID(contentVersion: expectedVersion, pageID: pageID) else {
            throw PersistenceMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "does not match the content version and page identifier"
            )
        }
        let supportLevel: LearningSupportLevel?
        if let supportLevelRawValue {
            guard let value = LearningSupportLevel(rawValue: supportLevelRawValue) else {
                throw PersistenceMappingSupport.invalid(
                    record: Self.recordName,
                    fieldPath: "supportLevelRawValue",
                    message: "contains an unsupported support level"
                )
            }
            supportLevel = value
        } else {
            supportLevel = nil
        }
        guard isCompleted == (completedAt != nil) else {
            throw PersistenceMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "completedAt",
                message: "must agree with the completion state"
            )
        }
        return (pageID, isCompleted, supportLevel)
    }

    func update(
        isCompleted: Bool,
        supportLevel: LearningSupportLevel?,
        timestamp: Date
    ) {
        if isCompleted, completedAt == nil {
            completedAt = timestamp
        } else if !isCompleted {
            completedAt = nil
        }
        self.isCompleted = isCompleted
        supportLevelRawValue = supportLevel?.rawValue
        updatedAt = timestamp
    }

    static func storageID(contentVersion: ContentVersion, pageID: String) -> String {
        PersistenceMappingSupport.storageID(
            contentVersion: contentVersion,
            value: pageID,
            namespace: "page-progress"
        )
    }

    private static func validate(pageID: String) throws {
        try PersistenceMappingSupport.validateIdentifier(
            pageID,
            record: recordName,
            fieldPath: "pageID"
        )
    }

    static let recordName = "PageProgressRecord"
}
