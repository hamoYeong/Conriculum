import Foundation
import SwiftData

@MainActor
final class UserDataStore {
    private let modelContext: ModelContext
    private let saveContext: (ModelContext) throws -> Void
    private var cachedProfileID: LocalProfileID?

    init(
        modelContainer: ModelContainer,
        saveContext: @escaping (ModelContext) throws -> Void = { try $0.save() }
    ) {
        modelContext = ModelContext(modelContainer)
        self.saveContext = saveContext
    }

    func localProfileID() throws -> LocalProfileID {
        if let cachedProfileID {
            return cachedProfileID
        }

        var descriptor = FetchDescriptor<LocalProfileRecord>(
            sortBy: [
                SortDescriptor(\LocalProfileRecord.createdAt),
                SortDescriptor(\LocalProfileRecord.id),
            ]
        )
        descriptor.fetchLimit = 1

        if let record = try records(
            matching: descriptor,
            operation: "localProfile.load"
        ).first {
            var profile = try record.domainValue()
            profile.lastOpenedAt = Date()
            try record.update(from: profile)
            try saveChanges(operation: "localProfile.touch")
            cachedProfileID = profile.id
            return profile.id
        }

        let timestamp = Date()
        let profile = LocalProfile(
            id: LocalProfileID(rawValue: UUID().uuidString.lowercased()),
            createdAt: timestamp,
            lastOpenedAt: timestamp
        )
        let record = try LocalProfileRecord(domainValue: profile)
        modelContext.insert(record)
        try saveChanges(operation: "localProfile.create")
        cachedProfileID = profile.id
        return profile.id
    }

    func loadProgress(chapterID: ChapterID) throws -> LearningProgress? {
        let profileID = try localProfileID()
        let profileValue = profileID.rawValue
        let chapterValue = chapterID.rawValue
        var descriptor = FetchDescriptor<LearningProgressRecord>(
            predicate: #Predicate {
                $0.profileID == profileValue && $0.chapterID == chapterValue
            }
        )
        descriptor.fetchLimit = 1

        return try records(
            matching: descriptor,
            operation: "loadProgress"
        ).first?.domainValue(profileID: profileID)
    }

    func saveProgress(_ progress: LearningProgress) throws {
        let profileID = try localProfileID()
        let profileValue = profileID.rawValue
        let chapterValue = progress.chapterID.rawValue
        var descriptor = FetchDescriptor<LearningProgressRecord>(
            predicate: #Predicate {
                $0.profileID == profileValue && $0.chapterID == chapterValue
            }
        )
        descriptor.fetchLimit = 1

        if let record = try records(
            matching: descriptor,
            operation: "saveProgress.lookup"
        ).first {
            try record.update(from: progress, profileID: profileID)
        } else {
            modelContext.insert(
                try LearningProgressRecord(
                    profileID: profileID,
                    domainValue: progress
                )
            )
        }
        try saveChanges(operation: "saveProgress")
    }

    func loadResponses(pageID: LearningPageID) throws -> [ActivityResponse] {
        let profileID = try localProfileID()
        let profileValue = profileID.rawValue
        let pageValue = pageID.rawValue
        let descriptor = FetchDescriptor<ActivityResponseRecord>(
            predicate: #Predicate {
                $0.profileID == profileValue && $0.pageID == pageValue
            },
            sortBy: [
                SortDescriptor(\ActivityResponseRecord.recordedAt),
                SortDescriptor(\ActivityResponseRecord.id),
            ]
        )

        return try records(
            matching: descriptor,
            operation: "loadResponses"
        ).map {
            try $0.domainValue(profileID: profileID)
        }
    }

    func saveResponse(_ response: ActivityResponse) throws {
        let profileID = try localProfileID()
        let responseID = response.id.rawValue
        var descriptor = FetchDescriptor<ActivityResponseRecord>(
            predicate: #Predicate { $0.id == responseID }
        )
        descriptor.fetchLimit = 1

        if let record = try records(
            matching: descriptor,
            operation: "saveResponse.lookup"
        ).first {
            try record.update(from: response, profileID: profileID)
        } else {
            modelContext.insert(
                try ActivityResponseRecord(
                    profileID: profileID,
                    domainValue: response
                )
            )
        }
        try saveChanges(operation: "saveResponse")
    }

    func loadEvidence(pageID: LearningPageID) throws -> [LearningEvidence] {
        let profileID = try localProfileID()
        let profileValue = profileID.rawValue
        let pageValue = pageID.rawValue
        let descriptor = FetchDescriptor<LearningEvidenceRecord>(
            predicate: #Predicate {
                $0.profileID == profileValue && $0.pageID == pageValue
            },
            sortBy: [
                SortDescriptor(\LearningEvidenceRecord.recordedAt),
                SortDescriptor(\LearningEvidenceRecord.id),
            ]
        )

        return try records(
            matching: descriptor,
            operation: "loadEvidence"
        ).map {
            try $0.domainValue(profileID: profileID)
        }
    }

    func saveEvidence(_ evidence: LearningEvidence) throws {
        let profileID = try localProfileID()
        let evidenceID = evidence.id.rawValue
        var descriptor = FetchDescriptor<LearningEvidenceRecord>(
            predicate: #Predicate { $0.id == evidenceID }
        )
        descriptor.fetchLimit = 1

        if let record = try records(
            matching: descriptor,
            operation: "saveEvidence.lookup"
        ).first {
            try record.update(from: evidence, profileID: profileID)
        } else {
            modelContext.insert(
                try LearningEvidenceRecord(
                    profileID: profileID,
                    domainValue: evidence
                )
            )
        }
        try saveChanges(operation: "saveEvidence")
    }

    /// Append-only exposure: returning to an earlier page must not relock knowledge.
    /// Uses the existing viewed evidence schema, so no store migration is required.
    func recordPageVisit(chapter: Chapter, pageID: LearningPageID) throws {
        guard chapter.page(id: pageID) != nil else { return }
        let progress = try loadProgress(chapterID: chapter.id)
        var pageIDs = LearningExposure.historicalPageIDs(chapter: chapter, progress: progress)
        if chapter.page(id: pageID)?.kind == .lesson { pageIDs.insert(pageID) }
        let profileID = try localProfileID()
        var pending: [LearningEvidenceRecord] = []
        for id in pageIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard try !loadEvidence(pageID: id).contains(where: { $0.kind == .viewed }) else { continue }
            let evidence = LearningEvidence(
                id: LearningEvidenceID(rawValue: "viewed:\(profileID.rawValue):\(id.rawValue)"),
                kind: .viewed, pageID: id, activityID: nil, responseID: nil,
                note: id == pageID ? nil : "기존 저장 진도에서 복원한 열람 이력",
                recordedAt: Date()
            )
            pending.append(try LearningEvidenceRecord(profileID: profileID, domainValue: evidence))
        }
        for record in pending { modelContext.insert(record) }
        if !pending.isEmpty { try saveChanges(operation: "recordPageVisit") }
    }

    func loadRevisions(conceptID: KnowledgeConceptID) throws -> [PersonalConceptRevision] {
        let profileID = try localProfileID()
        let profileValue = profileID.rawValue
        let conceptValue = conceptID.rawValue
        let descriptor = FetchDescriptor<PersonalConceptRevisionRecord>(
            predicate: #Predicate {
                $0.profileID == profileValue && $0.conceptID == conceptValue
            },
            sortBy: [
                SortDescriptor(\PersonalConceptRevisionRecord.createdAt),
                SortDescriptor(\PersonalConceptRevisionRecord.id),
            ]
        )

        return try records(
            matching: descriptor,
            operation: "loadRevisions"
        ).map {
            try $0.domainValue(profileID: profileID)
        }
    }

    func loadAllRevisions() throws -> [PersonalConceptRevision] {
        let profileID = try localProfileID()
        let profileValue = profileID.rawValue
        let descriptor = FetchDescriptor<PersonalConceptRevisionRecord>(
            predicate: #Predicate {
                $0.profileID == profileValue
            },
            sortBy: [
                SortDescriptor(\PersonalConceptRevisionRecord.createdAt),
                SortDescriptor(\PersonalConceptRevisionRecord.id),
            ]
        )

        return try records(
            matching: descriptor,
            operation: "loadAllRevisions"
        ).map {
            try $0.domainValue(profileID: profileID)
        }
    }

    func saveRevision(_ revision: PersonalConceptRevision) throws {
        let profileID = try localProfileID()
        let revisionID = revision.id.rawValue
        var descriptor = FetchDescriptor<PersonalConceptRevisionRecord>(
            predicate: #Predicate { $0.id == revisionID }
        )
        descriptor.fetchLimit = 1

        if let record = try records(
            matching: descriptor,
            operation: "saveRevision.lookup"
        ).first {
            try record.update(from: revision, profileID: profileID)
        } else {
            modelContext.insert(
                try PersonalConceptRevisionRecord(
                    profileID: profileID,
                    domainValue: revision
                )
            )
        }
        try saveChanges(operation: "saveRevision")
    }

    func loadRelations(conceptID: KnowledgeConceptID) throws -> [PersonalKnowledgeRelation] {
        let profileID = try localProfileID()
        let profileValue = profileID.rawValue
        let conceptValue = conceptID.rawValue
        let descriptor = FetchDescriptor<PersonalKnowledgeRelationRecord>(
            predicate: #Predicate {
                $0.profileID == profileValue
                    && ($0.sourceConceptID == conceptValue || $0.targetConceptID == conceptValue)
            },
            sortBy: [
                SortDescriptor(\PersonalKnowledgeRelationRecord.createdAt),
                SortDescriptor(\PersonalKnowledgeRelationRecord.id),
            ]
        )

        return try records(
            matching: descriptor,
            operation: "loadRelations"
        ).map {
            try $0.domainValue(profileID: profileID)
        }
    }

    func loadAllRelations() throws -> [PersonalKnowledgeRelation] {
        let profileID = try localProfileID()
        let profileValue = profileID.rawValue
        let descriptor = FetchDescriptor<PersonalKnowledgeRelationRecord>(
            predicate: #Predicate {
                $0.profileID == profileValue
            },
            sortBy: [
                SortDescriptor(\PersonalKnowledgeRelationRecord.createdAt),
                SortDescriptor(\PersonalKnowledgeRelationRecord.id),
            ]
        )

        return try records(
            matching: descriptor,
            operation: "loadAllRelations"
        ).map {
            try $0.domainValue(profileID: profileID)
        }
    }

    func saveRelation(_ relation: PersonalKnowledgeRelation) throws {
        let profileID = try localProfileID()
        let relationID = relation.id.rawValue
        var descriptor = FetchDescriptor<PersonalKnowledgeRelationRecord>(
            predicate: #Predicate { $0.id == relationID }
        )
        descriptor.fetchLimit = 1

        if let record = try records(
            matching: descriptor,
            operation: "saveRelation.lookup"
        ).first {
            try record.update(from: relation, profileID: profileID)
        } else {
            modelContext.insert(
                try PersonalKnowledgeRelationRecord(
                    profileID: profileID,
                    domainValue: relation
                )
            )
        }
        try saveChanges(operation: "saveRelation")
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

    private func saveChanges(operation: String) throws {
        do {
            try saveContext(modelContext)
        } catch {
            modelContext.rollback()
            throw PersistenceClientError.saveFailed(
                operation: operation,
                message: error.localizedDescription
            )
        }
    }
}
