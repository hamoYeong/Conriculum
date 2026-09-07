extension LearningEvidenceRecord {
    convenience init(
        profileID: LocalProfileID,
        domainValue evidence: V1LearningEvidence
    ) throws {
        try Self.validate(evidence, profileID: profileID)

        self.init(
            id: evidence.id.rawValue,
            profileID: profileID.rawValue,
            kindRawValue: evidence.kind.rawValue,
            pageID: evidence.pageID.rawValue,
            activityID: evidence.activityID?.rawValue,
            responseID: evidence.responseID?.rawValue,
            note: evidence.note,
            recordedAt: evidence.recordedAt
        )
    }

    func domainValue(profileID expectedProfileID: LocalProfileID) throws -> V1LearningEvidence {
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
            pageID,
            record: Self.recordName,
            fieldPath: "pageID"
        )
        if let activityID {
            try V1RecordMappingSupport.validateIdentifier(
                activityID,
                record: Self.recordName,
                fieldPath: "activityID"
            )
        }
        if let responseID {
            try V1RecordMappingSupport.validateIdentifier(
                responseID,
                record: Self.recordName,
                fieldPath: "responseID"
            )
            guard activityID != nil else {
                throw V1RecordMappingSupport.invalid(
                    record: Self.recordName,
                    fieldPath: "responseID",
                    message: "requires an activity reference"
                )
            }
        }
        guard let kind = V1LearningEvidenceKind(rawValue: kindRawValue) else {
            throw V1RecordMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "kindRawValue",
                message: "is not a supported learning evidence kind"
            )
        }

        return V1LearningEvidence(
            id: LearningEvidenceID(rawValue: id),
            kind: kind,
            pageID: LearningPageID(rawValue: pageID),
            activityID: activityID.map { LearningActivityID(rawValue: $0) },
            responseID: responseID.map { ActivityResponseID(rawValue: $0) },
            note: note,
            recordedAt: recordedAt
        )
    }

    func update(
        from evidence: V1LearningEvidence,
        profileID expectedProfileID: LocalProfileID
    ) throws {
        try Self.validate(evidence, profileID: expectedProfileID)
        try V1RecordMappingSupport.validateProfileID(
            profileID,
            expected: expectedProfileID,
            record: Self.recordName
        )
        guard id == evidence.id.rawValue else {
            throw V1RecordMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "cannot change an existing learning evidence identifier"
            )
        }

        kindRawValue = evidence.kind.rawValue
        pageID = evidence.pageID.rawValue
        activityID = evidence.activityID?.rawValue
        responseID = evidence.responseID?.rawValue
        note = evidence.note
        recordedAt = evidence.recordedAt
    }

    private static func validate(
        _ evidence: V1LearningEvidence,
        profileID: LocalProfileID
    ) throws {
        try V1RecordMappingSupport.validateIdentifier(
            profileID.rawValue,
            record: recordName,
            fieldPath: "profileID"
        )
        try V1RecordMappingSupport.validateIdentifier(
            evidence.id.rawValue,
            record: recordName,
            fieldPath: "id"
        )
        try V1RecordMappingSupport.validateIdentifier(
            evidence.pageID.rawValue,
            record: recordName,
            fieldPath: "pageID"
        )
        if let activityID = evidence.activityID?.rawValue {
            try V1RecordMappingSupport.validateIdentifier(
                activityID,
                record: recordName,
                fieldPath: "activityID"
            )
        }
        if let responseID = evidence.responseID?.rawValue {
            try V1RecordMappingSupport.validateIdentifier(
                responseID,
                record: recordName,
                fieldPath: "responseID"
            )
            guard evidence.activityID != nil else {
                throw V1RecordMappingSupport.invalid(
                    record: recordName,
                    fieldPath: "responseID",
                    message: "requires an activity reference"
                )
            }
        }
    }

    private static let recordName = "LearningEvidenceRecord"
}
