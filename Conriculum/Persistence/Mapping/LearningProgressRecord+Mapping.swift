extension LearningProgressRecord {
    convenience init(
        profileID: LocalProfileID,
        domainValue progress: V1LearningProgress
    ) throws {
        try Self.validate(progress, profileID: profileID)

        self.init(
            id: Self.storageID(profileID: profileID, chapterID: progress.chapterID),
            profileID: profileID.rawValue,
            chapterID: progress.chapterID.rawValue,
            currentPageID: progress.currentPageID.rawValue,
            completedPageIDs: progress.completedPageIDs.map(\.rawValue).sorted(),
            updatedAt: progress.updatedAt
        )
    }

    func domainValue(profileID expectedProfileID: LocalProfileID) throws -> V1LearningProgress {
        try RecordMappingSupport.validateProfileID(
            profileID,
            expected: expectedProfileID,
            record: Self.recordName
        )
        try RecordMappingSupport.validateIdentifier(
            chapterID,
            record: Self.recordName,
            fieldPath: "chapterID"
        )
        try RecordMappingSupport.validateIdentifier(
            currentPageID,
            record: Self.recordName,
            fieldPath: "currentPageID"
        )
        for completedPageID in completedPageIDs {
            try RecordMappingSupport.validateIdentifier(
                completedPageID,
                record: Self.recordName,
                fieldPath: "completedPageIDs"
            )
        }
        guard Set(completedPageIDs).count == completedPageIDs.count else {
            throw RecordMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "completedPageIDs",
                message: "must not contain duplicate page identifiers"
            )
        }

        let chapterID = ChapterID(rawValue: chapterID)
        guard id == Self.storageID(profileID: expectedProfileID, chapterID: chapterID) else {
            throw RecordMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "id",
                message: "does not match the profile and chapter identifiers"
            )
        }

        return V1LearningProgress(
            chapterID: chapterID,
            currentPageID: LearningPageID(rawValue: currentPageID),
            completedPageIDs: Set(completedPageIDs.map { LearningPageID(rawValue: $0) }),
            updatedAt: updatedAt
        )
    }

    func update(
        from progress: V1LearningProgress,
        profileID expectedProfileID: LocalProfileID
    ) throws {
        try Self.validate(progress, profileID: expectedProfileID)
        try RecordMappingSupport.validateProfileID(
            profileID,
            expected: expectedProfileID,
            record: Self.recordName
        )
        guard chapterID == progress.chapterID.rawValue,
              id == Self.storageID(profileID: expectedProfileID, chapterID: progress.chapterID)
        else {
            throw RecordMappingSupport.invalid(
                record: Self.recordName,
                fieldPath: "chapterID",
                message: "cannot change an existing progress identity"
            )
        }

        currentPageID = progress.currentPageID.rawValue
        completedPageIDs = progress.completedPageIDs.map(\.rawValue).sorted()
        updatedAt = progress.updatedAt
    }

    static func storageID(
        profileID: LocalProfileID,
        chapterID: ChapterID
    ) -> String {
        let profileValue = profileID.rawValue
        return "progress:\(profileValue.utf8.count):\(profileValue)\(chapterID.rawValue)"
    }

    private static func validate(
        _ progress: V1LearningProgress,
        profileID: LocalProfileID
    ) throws {
        try RecordMappingSupport.validateIdentifier(
            profileID.rawValue,
            record: recordName,
            fieldPath: "profileID"
        )
        try RecordMappingSupport.validateIdentifier(
            progress.chapterID.rawValue,
            record: recordName,
            fieldPath: "chapterID"
        )
        try RecordMappingSupport.validateIdentifier(
            progress.currentPageID.rawValue,
            record: recordName,
            fieldPath: "currentPageID"
        )
        for completedPageID in progress.completedPageIDs {
            try RecordMappingSupport.validateIdentifier(
                completedPageID.rawValue,
                record: recordName,
                fieldPath: "completedPageIDs"
            )
        }
    }

    private static let recordName = "LearningProgressRecord"
}
