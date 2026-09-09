extension LocalProfileRecord {
    convenience init(domainValue profile: V1LocalProfile) throws {
        try V1RecordMappingSupport.validateIdentifier(
            profile.id.rawValue,
            record: Self.recordName,
            fieldPath: "id"
        )

        self.init(
            id: profile.id.rawValue,
            createdAt: profile.createdAt,
            lastOpenedAt: profile.lastOpenedAt
        )
    }

    func domainValue() throws -> V1LocalProfile {
        try V1RecordMappingSupport.validateIdentifier(
            id,
            record: Self.recordName,
            fieldPath: "id"
        )

        return V1LocalProfile(
            id: LocalProfileID(rawValue: id),
            createdAt: createdAt,
            lastOpenedAt: lastOpenedAt
        )
    }

    func update(from profile: V1LocalProfile) throws {
        guard id == profile.id.rawValue else {
            throw V1RecordMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "cannot change an existing local profile identifier"
            )
        }

        createdAt = profile.createdAt
        lastOpenedAt = profile.lastOpenedAt
    }

    private static let recordName = "LocalProfileRecord"
}
