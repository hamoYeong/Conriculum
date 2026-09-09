import Foundation

extension PageProgressRecord {
    convenience init(
        pageID: String,
        isCompleted: Bool,
        supportLevel: LearningSupportLevel?,
        timestamp: Date
    ) throws {
        try Self.validate(pageID: pageID)
        self.init(
            id: Self.storageID(pageID: pageID),
            pageID: pageID,
            isCompleted: isCompleted,
            supportLevelRawValue: supportLevel?.rawValue,
            completedAt: isCompleted ? timestamp : nil,
            updatedAt: timestamp
        )
    }

    func values() throws -> (
        pageID: String,
        isCompleted: Bool,
        supportLevel: LearningSupportLevel?
    ) {
        try Self.validate(pageID: pageID)
        guard id == Self.storageID(pageID: pageID) else {
            throw PersistenceMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "does not match the page identifier"
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

    static func storageID(pageID: String) -> String {
        PersistenceMappingSupport.storageID(
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
