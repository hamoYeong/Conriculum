extension ActivityResponseRecord {
    convenience init(
        profileID: LocalProfileID,
        domainValue response: V1ActivityResponse
    ) throws {
        try Self.validate(response, profileID: profileID)
        let fieldsPayload = try V1RecordMappingSupport.encode(
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

    func domainValue(profileID expectedProfileID: LocalProfileID) throws -> V1ActivityResponse {
        try V1RecordMappingSupport.validateProfileID(
            profileID,
            expected: expectedProfileID,
            record: Self.recordName
        )
        try V1RecordMappingSupport.validateIdentifier(
            id,
            record: Self.recordName,
            fieldPath: "id"
        )
        try V1RecordMappingSupport.validateIdentifier(
            activityID,
            record: Self.recordName,
            fieldPath: "activityID"
        )
        try V1RecordMappingSupport.validateIdentifier(
            pageID,
            record: Self.recordName,
            fieldPath: "pageID"
        )

        let fields = try V1RecordMappingSupport.decode(
            [V1ActivityResponseField].self,
            from: fieldsPayload,
            record: Self.recordName,
            fieldPath: "fieldsPayload"
        )
        try Self.validateFields(fields)

        return V1ActivityResponse(
            id: ActivityResponseID(rawValue: id),
            activityID: LearningActivityID(rawValue: activityID),
            pageID: LearningPageID(rawValue: pageID),
            fields: fields,
            recordedAt: recordedAt
        )
    }

    func update(
        from response: V1ActivityResponse,
        profileID expectedProfileID: LocalProfileID
    ) throws {
        try Self.validate(response, profileID: expectedProfileID)
        try V1RecordMappingSupport.validateProfileID(
            profileID,
            expected: expectedProfileID,
            record: Self.recordName
        )
        guard id == response.id.rawValue else {
            throw V1RecordMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "cannot change an existing activity response identifier"
            )
        }

        activityID = response.activityID.rawValue
        pageID = response.pageID.rawValue
        fieldsPayload = try V1RecordMappingSupport.encode(
            response.fields,
            record: Self.recordName,
            fieldPath: "fieldsPayload"
        )
        recordedAt = response.recordedAt
    }

    private static func validate(
        _ response: V1ActivityResponse,
        profileID: LocalProfileID
    ) throws {
        try V1RecordMappingSupport.validateIdentifier(
            profileID.rawValue,
            record: recordName,
            fieldPath: "profileID"
        )
        try V1RecordMappingSupport.validateIdentifier(
            response.id.rawValue,
            record: recordName,
            fieldPath: "id"
        )
        try V1RecordMappingSupport.validateIdentifier(
            response.activityID.rawValue,
            record: recordName,
            fieldPath: "activityID"
        )
        try V1RecordMappingSupport.validateIdentifier(
            response.pageID.rawValue,
            record: recordName,
            fieldPath: "pageID"
        )
        try validateFields(response.fields)
    }

    private static func validateFields(_ fields: [V1ActivityResponseField]) throws {
        for field in fields {
            try V1RecordMappingSupport.validateIdentifier(
                field.key,
                record: recordName,
                fieldPath: "fieldsPayload.key"
            )
        }
        guard Set(fields.map(\.key)).count == fields.count else {
            throw V1RecordMappingSupport.invalid(
                record: recordName,
                fieldPath: "fieldsPayload.key",
                message: "must not contain duplicate response field keys"
            )
        }
    }

    private static let recordName = "ActivityResponseRecord"
}
