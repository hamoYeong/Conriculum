import Foundation

extension GameResponseRecord {
    convenience init(
        contentVersion: ContentVersion,
        domainValue response: GameResponse
    ) throws {
        try Self.validate(response)
        self.init(
            id: Self.storageID(
                contentVersion: contentVersion,
                activityID: response.activityID
            ),
            contentVersion: contentVersion.rawValue,
            activityID: response.activityID,
            selectedOptionIDs: response.selectedOptionIDs.sorted(),
            matchesPayload: try PersistenceMappingSupport.encode(
                response.matches,
                record: Self.recordName,
                fieldPath: "matchesPayload"
            ),
            isCorrect: response.isCorrect,
            attempts: response.attempts,
            answeredAt: response.answeredAt
        )
    }

    func domainValue(contentVersion expectedVersion: ContentVersion) throws -> GameResponse {
        guard contentVersion == expectedVersion.rawValue else {
            throw PersistenceMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "contentVersion",
                message: "does not belong to the requested content version"
            )
        }
        guard id == Self.storageID(
            contentVersion: expectedVersion,
            activityID: activityID
        ) else {
            throw PersistenceMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "does not match the content version and activity identifier"
            )
        }
        let matches = try PersistenceMappingSupport.decode(
            [String: String].self,
            from: matchesPayload,
            record: Self.recordName,
            fieldPath: "matchesPayload"
        )
        let response = GameResponse(
            activityID: activityID,
            selectedOptionIDs: Set(selectedOptionIDs),
            matches: matches,
            isCorrect: isCorrect,
            attempts: attempts,
            answeredAt: answeredAt
        )
        try Self.validate(response)
        guard Set(selectedOptionIDs).count == selectedOptionIDs.count else {
            throw PersistenceMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "selectedOptionIDs",
                message: "must not contain duplicate option identifiers"
            )
        }
        return response
    }

    func update(from response: GameResponse) throws {
        try Self.validate(response)
        guard activityID == response.activityID else {
            throw PersistenceMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "activityID",
                message: "cannot change an existing response identity"
            )
        }
        selectedOptionIDs = response.selectedOptionIDs.sorted()
        matchesPayload = try PersistenceMappingSupport.encode(
            response.matches,
            record: Self.recordName,
            fieldPath: "matchesPayload"
        )
        isCorrect = response.isCorrect
        attempts = response.attempts
        answeredAt = response.answeredAt
    }

    static func storageID(contentVersion: ContentVersion, activityID: String) -> String {
        PersistenceMappingSupport.storageID(
            contentVersion: contentVersion,
            value: activityID,
            namespace: "game-response"
        )
    }

    private static func validate(_ response: GameResponse) throws {
        try PersistenceMappingSupport.validateIdentifier(
            response.activityID,
            record: recordName,
            fieldPath: "activityID"
        )
        for optionID in response.selectedOptionIDs {
            try PersistenceMappingSupport.validateIdentifier(
                optionID,
                record: recordName,
                fieldPath: "selectedOptionIDs"
            )
        }
        for (leftID, rightID) in response.matches {
            try PersistenceMappingSupport.validateIdentifier(
                leftID,
                record: recordName,
                fieldPath: "matches"
            )
            try PersistenceMappingSupport.validateIdentifier(
                rightID,
                record: recordName,
                fieldPath: "matches"
            )
        }
        guard response.attempts > 0 else {
            throw PersistenceMappingSupport.invalid(
                record: recordName,
                fieldPath: "attempts",
                message: "must be greater than zero"
            )
        }
        guard !response.selectedOptionIDs.isEmpty || !response.matches.isEmpty else {
            throw PersistenceMappingSupport.invalid(
                record: recordName,
                fieldPath: "response",
                message: "must contain a selection or a completed match"
            )
        }
    }

    static let recordName = "GameResponseRecord"
}
