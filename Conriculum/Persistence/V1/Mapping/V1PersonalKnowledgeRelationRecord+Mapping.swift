extension PersonalKnowledgeRelationRecord {
    convenience init(
        profileID: LocalProfileID,
        domainValue relation: PersonalKnowledgeRelation
    ) throws {
        try Self.validate(relation, profileID: profileID)

        self.init(
            id: relation.id.rawValue,
            profileID: profileID.rawValue,
            sourceConceptID: relation.sourceConceptID.rawValue,
            targetConceptID: relation.targetConceptID.rawValue,
            statement: relation.statement,
            reason: relation.reason,
            evidenceActivityID: relation.evidenceActivityID.rawValue,
            createdAt: relation.createdAt
        )
    }

    func domainValue(profileID expectedProfileID: LocalProfileID) throws -> PersonalKnowledgeRelation {
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
            sourceConceptID,
            record: Self.recordName,
            fieldPath: "sourceConceptID"
        )
        try V1RecordMappingSupport.validateIdentifier(
            targetConceptID,
            record: Self.recordName,
            fieldPath: "targetConceptID"
        )
        try V1RecordMappingSupport.validateIdentifier(
            evidenceActivityID,
            record: Self.recordName,
            fieldPath: "evidenceActivityID"
        )
        try Self.validateDistinctConcepts(
            sourceConceptID: sourceConceptID,
            targetConceptID: targetConceptID
        )

        return PersonalKnowledgeRelation(
            id: PersonalKnowledgeRelationID(rawValue: id),
            sourceConceptID: KnowledgeConceptID(rawValue: sourceConceptID),
            targetConceptID: KnowledgeConceptID(rawValue: targetConceptID),
            statement: statement,
            reason: reason,
            evidenceActivityID: LearningActivityID(rawValue: evidenceActivityID),
            createdAt: createdAt
        )
    }

    func update(
        from relation: PersonalKnowledgeRelation,
        profileID expectedProfileID: LocalProfileID
    ) throws {
        try Self.validate(relation, profileID: expectedProfileID)
        try V1RecordMappingSupport.validateProfileID(
            profileID,
            expected: expectedProfileID,
            record: Self.recordName
        )
        guard id == relation.id.rawValue else {
            throw V1RecordMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "cannot change an existing knowledge relation identifier"
            )
        }

        sourceConceptID = relation.sourceConceptID.rawValue
        targetConceptID = relation.targetConceptID.rawValue
        statement = relation.statement
        reason = relation.reason
        evidenceActivityID = relation.evidenceActivityID.rawValue
        createdAt = relation.createdAt
    }

    private static func validate(
        _ relation: PersonalKnowledgeRelation,
        profileID: LocalProfileID
    ) throws {
        try V1RecordMappingSupport.validateIdentifier(
            profileID.rawValue,
            record: recordName,
            fieldPath: "profileID"
        )
        try V1RecordMappingSupport.validateIdentifier(
            relation.id.rawValue,
            record: recordName,
            fieldPath: "id"
        )
        try V1RecordMappingSupport.validateIdentifier(
            relation.sourceConceptID.rawValue,
            record: recordName,
            fieldPath: "sourceConceptID"
        )
        try V1RecordMappingSupport.validateIdentifier(
            relation.targetConceptID.rawValue,
            record: recordName,
            fieldPath: "targetConceptID"
        )
        try V1RecordMappingSupport.validateIdentifier(
            relation.evidenceActivityID.rawValue,
            record: recordName,
            fieldPath: "evidenceActivityID"
        )
        try validateDistinctConcepts(
            sourceConceptID: relation.sourceConceptID.rawValue,
            targetConceptID: relation.targetConceptID.rawValue
        )
    }

    private static func validateDistinctConcepts(
        sourceConceptID: String,
        targetConceptID: String
    ) throws {
        guard sourceConceptID != targetConceptID else {
            throw V1RecordMappingSupport.invalid(
                record: recordName,
                fieldPath: "targetConceptID",
                message: "must reference a concept different from sourceConceptID"
            )
        }
    }

    private static let recordName = "PersonalKnowledgeRelationRecord"
}
