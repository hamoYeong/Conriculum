extension LocalProfileRecord {
    convenience init(domainValue profile: LocalProfile) throws {
        try RecordMappingSupport.validateIdentifier(
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

    func domainValue() throws -> LocalProfile {
        try RecordMappingSupport.validateIdentifier(
            id,
            record: Self.recordName,
            fieldPath: "id"
        )

        return LocalProfile(
            id: LocalProfileID(rawValue: id),
            createdAt: createdAt,
            lastOpenedAt: lastOpenedAt
        )
    }

    func update(from profile: LocalProfile) throws {
        guard id == profile.id.rawValue else {
            throw RecordMappingSupport.invalid(
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
