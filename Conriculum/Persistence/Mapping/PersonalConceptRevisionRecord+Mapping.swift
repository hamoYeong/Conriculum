extension PersonalConceptRevisionRecord {
    convenience init(
        profileID: LocalProfileID,
        domainValue revision: PersonalConceptRevision
    ) throws {
        try Self.validate(revision, profileID: profileID)
        let examplesPayload = try RecordMappingSupport.encode(
            revision.examples,
            record: Self.recordName,
            fieldPath: "examplesPayload"
        )

        self.init(
            id: revision.id.rawValue,
            profileID: profileID.rawValue,
            conceptID: revision.conceptID.rawValue,
            personalTitle: revision.personalTitle,
            explanation: revision.explanation,
            examplesPayload: examplesPayload,
            previousRevisionID: revision.previousRevisionID?.rawValue,
            evidenceActivityID: revision.evidenceActivityID.rawValue,
            createdAt: revision.createdAt
        )
    }

    func domainValue(profileID expectedProfileID: LocalProfileID) throws -> PersonalConceptRevision {
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
            conceptID,
            record: Self.recordName,
            fieldPath: "conceptID"
        )
        try RecordMappingSupport.validateIdentifier(
            evidenceActivityID,
            record: Self.recordName,
            fieldPath: "evidenceActivityID"
        )
        if let previousRevisionID {
            try RecordMappingSupport.validateIdentifier(
                previousRevisionID,
                record: Self.recordName,
                fieldPath: "previousRevisionID"
            )
            guard previousRevisionID != id else {
                throw RecordMappingSupport.invalid(
                    record: Self.recordName,
                    fieldPath: "previousRevisionID",
                    message: "cannot reference the same revision"
                )
            }
        }

        let examples = try RecordMappingSupport.decode(
            [PersonalExample].self,
            from: examplesPayload,
            record: Self.recordName,
            fieldPath: "examplesPayload"
        )
        try Self.validateExamples(examples)

        return PersonalConceptRevision(
            id: PersonalConceptRevisionID(rawValue: id),
            conceptID: KnowledgeConceptID(rawValue: conceptID),
            personalTitle: personalTitle,
            explanation: explanation,
            examples: examples,
            previousRevisionID: previousRevisionID.map {
                PersonalConceptRevisionID(rawValue: $0)
            },
            evidenceActivityID: LearningActivityID(rawValue: evidenceActivityID),
            createdAt: createdAt
        )
    }

    func update(
        from revision: PersonalConceptRevision,
        profileID expectedProfileID: LocalProfileID
    ) throws {
        try Self.validate(revision, profileID: expectedProfileID)
        try RecordMappingSupport.validateProfileID(
            profileID,
            expected: expectedProfileID,
            record: Self.recordName
        )
        guard id == revision.id.rawValue else {
            throw RecordMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "cannot change an existing concept revision identifier"
            )
        }

        conceptID = revision.conceptID.rawValue
        personalTitle = revision.personalTitle
        explanation = revision.explanation
        examplesPayload = try RecordMappingSupport.encode(
            revision.examples,
            record: Self.recordName,
            fieldPath: "examplesPayload"
        )
        previousRevisionID = revision.previousRevisionID?.rawValue
        evidenceActivityID = revision.evidenceActivityID.rawValue
        createdAt = revision.createdAt
    }

    private static func validate(
        _ revision: PersonalConceptRevision,
        profileID: LocalProfileID
    ) throws {
        try RecordMappingSupport.validateIdentifier(
            profileID.rawValue,
            record: recordName,
            fieldPath: "profileID"
        )
        try RecordMappingSupport.validateIdentifier(
            revision.id.rawValue,
            record: recordName,
            fieldPath: "id"
        )
        try RecordMappingSupport.validateIdentifier(
            revision.conceptID.rawValue,
            record: recordName,
            fieldPath: "conceptID"
        )
        try RecordMappingSupport.validateIdentifier(
            revision.evidenceActivityID.rawValue,
            record: recordName,
            fieldPath: "evidenceActivityID"
        )
        if let previousRevisionID = revision.previousRevisionID?.rawValue {
            try RecordMappingSupport.validateIdentifier(
                previousRevisionID,
                record: recordName,
                fieldPath: "previousRevisionID"
            )
            guard previousRevisionID != revision.id.rawValue else {
                throw RecordMappingSupport.invalid(
                    record: recordName,
                    fieldPath: "previousRevisionID",
                    message: "cannot reference the same revision"
                )
            }
        }
        try validateExamples(revision.examples)
    }

    private static func validateExamples(_ examples: [PersonalExample]) throws {
        for example in examples {
            try RecordMappingSupport.validateIdentifier(
                example.id.rawValue,
                record: recordName,
                fieldPath: "examplesPayload.id"
            )
        }
        guard Set(examples.map(\.id)).count == examples.count else {
            throw RecordMappingSupport.invalid(
                record: recordName,
                fieldPath: "examplesPayload.id",
                message: "must not contain duplicate personal example identifiers"
            )
        }
    }

    private static let recordName = "PersonalConceptRevisionRecord"
}
