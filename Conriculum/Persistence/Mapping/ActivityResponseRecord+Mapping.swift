extension ActivityResponseRecord {
    convenience init(
        profileID: LocalProfileID,
        domainValue response: ActivityResponse
    ) throws {
        try Self.validate(response, profileID: profileID)
        let fieldsPayload = try RecordMappingSupport.encode(
            response.fields,
            record: Self.recordName,
            fieldPath: "fieldsPayload"
        )

        self.init(
            id: response.id.rawValue,
            profileID: profileID.rawValue,
            activityID: response.activityID.rawValue,
            pageID: response.pageID.rawValue,
            fieldsPayload: fieldsPayload,
            recordedAt: response.recordedAt
        )
    }

    func domainValue(profileID expectedProfileID: LocalProfileID) throws -> ActivityResponse {
        try RecordMappingSupport.validateProfileID(
            profileID,
            expected: expectedProfileID,
            record: Self.recordName
        )
        try RecordMappingSupport.validateIdentifier(
            id,
            record: Self.recordName,
            fieldPath: "id"
        )
        try RecordMappingSupport.validateIdentifier(
            activityID,
            record: Self.recordName,
            fieldPath: "activityID"
        )
        try RecordMappingSupport.validateIdentifier(
            pageID,
            record: Self.recordName,
            fieldPath: "pageID"
        )

        let fields = try RecordMappingSupport.decode(
            [ActivityResponseField].self,
            from: fieldsPayload,
            record: Self.recordName,
            fieldPath: "fieldsPayload"
        )
        try Self.validateFields(fields)

        return ActivityResponse(
            id: ActivityResponseID(rawValue: id),
            activityID: LearningActivityID(rawValue: activityID),
            pageID: LearningPageID(rawValue: pageID),
            fields: fields,
            recordedAt: recordedAt
        )
    }

    func update(
        from response: ActivityResponse,
        profileID expectedProfileID: LocalProfileID
    ) throws {
        try Self.validate(response, profileID: expectedProfileID)
        try RecordMappingSupport.validateProfileID(
            profileID,
            expected: expectedProfileID,
            record: Self.recordName
        )
        guard id == response.id.rawValue else {
            throw RecordMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "cannot change an existing activity response identifier"
            )
        }

        activityID = response.activityID.rawValue
        pageID = response.pageID.rawValue
        fieldsPayload = try RecordMappingSupport.encode(
            response.fields,
            record: Self.recordName,
            fieldPath: "fieldsPayload"
        )
        recordedAt = response.recordedAt
    }

    private static func validate(
        _ response: ActivityResponse,
        profileID: LocalProfileID
    ) throws {
        try RecordMappingSupport.validateIdentifier(
            profileID.rawValue,
            record: recordName,
            fieldPath: "profileID"
        )
        try RecordMappingSupport.validateIdentifier(
            response.id.rawValue,
            record: recordName,
            fieldPath: "id"
        )
        try RecordMappingSupport.validateIdentifier(
            response.activityID.rawValue,
            record: recordName,
            fieldPath: "activityID"
        )
        try RecordMappingSupport.validateIdentifier(
            response.pageID.rawValue,
            record: recordName,
            fieldPath: "pageID"
        )
        try validateFields(response.fields)
    }

    private static func validateFields(_ fields: [ActivityResponseField]) throws {
        for field in fields {
            try RecordMappingSupport.validateIdentifier(
                field.key,
                record: recordName,
                fieldPath: "fieldsPayload.key"
            )
        }
        guard Set(fields.map(\.key)).count == fields.count else {
            throw RecordMappingSupport.invalid(
                record: recordName,
                fieldPath: "fieldsPayload.key",
                message: "must not contain duplicate response field keys"
            )
        }
    }

    private static let recordName = "ActivityResponseRecord"
}
