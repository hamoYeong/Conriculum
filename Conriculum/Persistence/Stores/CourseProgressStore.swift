import Foundation
import SwiftData

@MainActor
final class CourseProgressStore {
    private let contentVersion: ContentVersion
    private let modelContext: ModelContext
    private let now: () -> Date
    private let saveContext: (ModelContext) throws -> Void

    init(
        modelContainer: ModelContainer,
        contentVersion: ContentVersion = .v2,
        now: @escaping () -> Date = Date.init,
        saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.contentVersion = contentVersion
        modelContext = ModelContext(modelContainer)
        self.now = now
        self.saveContext = saveContext
    }

    func load() throws -> CourseProgress? {
        let metadata = try progressRecords(operation: "courseProgress.load")
        let pages = try pageRecords(operation: "pageProgress.load")
        let responses = try responseRecords(operation: "gameResponse.load")

        guard let record = metadata.first else {
            guard pages.isEmpty, responses.isEmpty else {
                throw PersistenceMappingSupport.invalid(
                    record: CourseProgressRecord.recordName,
                    fieldPath: "id",
                    message: "is missing while child progress records exist"
                )
            }
            return nil
        }
        guard metadata.count == 1 else {
            throw PersistenceMappingSupport.invalid(
                record: CourseProgressRecord.recordName,
                fieldPath: "contentVersion",
                message: "must contain one record per content version"
            )
        }
        try record.validate(contentVersion: contentVersion)

        var completedPageIDs: Set<String> = []
        var supportLevelsByPageID: [String: LearningSupportLevel] = [:]
        var loadedPageIDs: Set<String> = []
        for pageRecord in pages {
            let value = try pageRecord.values(contentVersion: contentVersion)
            guard loadedPageIDs.insert(value.pageID).inserted else {
                throw PersistenceMappingSupport.invalid(
                    record: PageProgressRecord.recordName,
                    fieldPath: "pageID",
                    message: "must be unique within a content version"
                )
            }
            if value.isCompleted { completedPageIDs.insert(value.pageID) }
            if let supportLevel = value.supportLevel {
                supportLevelsByPageID[value.pageID] = supportLevel
            }
        }

        var activityResponses: [String: GameResponse] = [:]
        for responseRecord in responses {
            let response = try responseRecord.domainValue(contentVersion: contentVersion)
            guard activityResponses.updateValue(response, forKey: response.activityID) == nil else {
                throw PersistenceMappingSupport.invalid(
                    record: GameResponseRecord.recordName,
                    fieldPath: "activityID",
                    message: "must be unique within a content version"
                )
            }
        }

        return CourseProgress(
            lastVisitedPageID: record.lastVisitedPageID,
            completedPageIDs: completedPageIDs,
            activityResponses: activityResponses,
            supportLevelsByPageID: supportLevelsByPageID
        )
    }

    func save(_ progress: CourseProgress) throws {
        try validate(progress)
        let timestamp = now()

        do {
            try upsertMetadata(progress, timestamp: timestamp)
            try synchronizePages(progress, timestamp: timestamp)
            try synchronizeResponses(progress)
            try saveContext(modelContext)
        } catch let error as PersistenceClientError {
            modelContext.rollback()
            throw error
        } catch {
            modelContext.rollback()
            throw PersistenceClientError.saveFailed(
                operation: "courseProgress.save",
                message: error.localizedDescription
            )
        }
    }

    private func upsertMetadata(
        _ progress: CourseProgress,
        timestamp: Date
    ) throws {
        let records = try progressRecords(operation: "courseProgress.save.lookup")
        guard records.count <= 1 else {
            throw PersistenceMappingSupport.invalid(
                record: CourseProgressRecord.recordName,
                fieldPath: "contentVersion",
                message: "must contain one record per content version"
            )
        }
        if let record = records.first {
            try record.validate(contentVersion: contentVersion)
            try record.update(
                lastVisitedPageID: progress.lastVisitedPageID,
                updatedAt: timestamp
            )
        } else {
            modelContext.insert(
                try CourseProgressRecord(
                    contentVersion: contentVersion,
                    lastVisitedPageID: progress.lastVisitedPageID,
                    updatedAt: timestamp
                )
            )
        }
    }

    private func synchronizePages(
        _ progress: CourseProgress,
        timestamp: Date
    ) throws {
        let records = try pageRecords(operation: "pageProgress.save.lookup")
        var existing: [String: PageProgressRecord] = [:]
        for record in records {
            guard existing.updateValue(record, forKey: record.pageID) == nil else {
                throw PersistenceMappingSupport.invalid(
                    record: PageProgressRecord.recordName,
                    fieldPath: "pageID",
                    message: "must be unique within a content version"
                )
            }
        }
        let desiredPageIDs = progress.completedPageIDs
            .union(progress.supportLevelsByPageID.keys)

        for pageID in desiredPageIDs {
            let isCompleted = progress.completedPageIDs.contains(pageID)
            let supportLevel = progress.supportLevelsByPageID[pageID]
            if let record = existing[pageID] {
                _ = try record.values(contentVersion: contentVersion)
                record.update(
                    isCompleted: isCompleted,
                    supportLevel: supportLevel,
                    timestamp: timestamp
                )
            } else {
                modelContext.insert(
                    try PageProgressRecord(
                        contentVersion: contentVersion,
                        pageID: pageID,
                        isCompleted: isCompleted,
                        supportLevel: supportLevel,
                        timestamp: timestamp
                    )
                )
            }
        }

        for record in records where !desiredPageIDs.contains(record.pageID) {
            modelContext.delete(record)
        }
    }

    private func synchronizeResponses(_ progress: CourseProgress) throws {
        let records = try responseRecords(operation: "gameResponse.save.lookup")
        var existing: [String: GameResponseRecord] = [:]
        for record in records {
            guard existing.updateValue(record, forKey: record.activityID) == nil else {
                throw PersistenceMappingSupport.invalid(
                    record: GameResponseRecord.recordName,
                    fieldPath: "activityID",
                    message: "must be unique within a content version"
                )
            }
        }

        for (activityID, response) in progress.activityResponses {
            guard activityID == response.activityID else {
                throw PersistenceMappingSupport.invalid(
                    record: GameResponseRecord.recordName,
                    fieldPath: "activityResponses",
                    message: "dictionary key must match the response activity identifier"
                )
            }
            if let record = existing[activityID] {
                _ = try record.domainValue(contentVersion: contentVersion)
                try record.update(from: response)
            } else {
                modelContext.insert(
                    try GameResponseRecord(
                        contentVersion: contentVersion,
                        domainValue: response
                    )
                )
            }
        }

        for record in records where progress.activityResponses[record.activityID] == nil {
            modelContext.delete(record)
        }
    }

    private func validate(_ progress: CourseProgress) throws {
        if let lastVisitedPageID = progress.lastVisitedPageID {
            try PersistenceMappingSupport.validateIdentifier(
                lastVisitedPageID,
                record: CourseProgressRecord.recordName,
                fieldPath: "lastVisitedPageID"
            )
        }
        for pageID in progress.completedPageIDs.union(progress.supportLevelsByPageID.keys) {
            try PersistenceMappingSupport.validateIdentifier(
                pageID,
                record: PageProgressRecord.recordName,
                fieldPath: "pageID"
            )
        }
    }

    private func progressRecords(operation: String) throws -> [CourseProgressRecord] {
        let version = contentVersion.rawValue
        return try records(
            matching: FetchDescriptor<CourseProgressRecord>(
                predicate: #Predicate { $0.contentVersion == version }
            ),
            operation: operation
        )
    }

    private func pageRecords(operation: String) throws -> [PageProgressRecord] {
        let version = contentVersion.rawValue
        return try records(
            matching: FetchDescriptor<PageProgressRecord>(
                predicate: #Predicate { $0.contentVersion == version },
                sortBy: [SortDescriptor(\PageProgressRecord.pageID)]
            ),
            operation: operation
        )
    }

    private func responseRecords(operation: String) throws -> [GameResponseRecord] {
        let version = contentVersion.rawValue
        return try records(
            matching: FetchDescriptor<GameResponseRecord>(
                predicate: #Predicate { $0.contentVersion == version },
                sortBy: [SortDescriptor(\GameResponseRecord.activityID)]
            ),
            operation: operation
        )
    }

    private func records<Record: PersistentModel>(
        matching descriptor: FetchDescriptor<Record>,
        operation: String
    ) throws -> [Record] {
        do {
            return try modelContext.fetch(descriptor)
        } catch let error as PersistenceClientError {
            throw error
        } catch {
            throw PersistenceClientError.loadFailed(
                operation: operation,
                message: error.localizedDescription
            )
        }
    }
}
