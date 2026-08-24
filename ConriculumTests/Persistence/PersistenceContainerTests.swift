import Foundation
import SwiftData
import Testing
@testable import Conriculum

@MainActor
struct PersistenceContainerTests {
    @Test
    func schemaContainsEveryUserOwnedRecord() {
        let modelNames = Set(
            ConriculumPersistenceSchema.schema.entities.map(\.name)
        )

        #expect(
            modelNames == [
                "LocalProfileRecord",
                "LearningProgressRecord",
                "ActivityResponseRecord",
                "LearningEvidenceRecord",
                "PersonalConceptRevisionRecord",
                "PersonalKnowledgeRelationRecord",
            ]
        )
    }

    @Test
    func inMemoryContainerStoresEveryRecordKind() throws {
        let container = try PersistenceContainerFactory.inMemory()
        let context = ModelContext(container)
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)

        context.insert(
            LocalProfileRecord(
                id: "profile-local",
                createdAt: timestamp,
                lastOpenedAt: timestamp
            )
        )
        context.insert(
            LearningProgressRecord(
                id: "progress-01",
                profileID: "profile-local",
                chapterID: "chapter-02",
                currentPageID: "page-02-01",
                completedPageIDs: ["page-02-00"],
                updatedAt: timestamp
            )
        )
        context.insert(
            ActivityResponseRecord(
                id: "response-01",
                profileID: "profile-local",
                activityID: "activity-01",
                pageID: "page-02-01",
                fieldsPayload: Data("[]".utf8),
                recordedAt: timestamp
            )
        )
        context.insert(
            LearningEvidenceRecord(
                id: "evidence-01",
                profileID: "profile-local",
                kindRawValue: "viewed",
                pageID: "page-02-01",
                activityID: nil,
                responseID: nil,
                note: nil,
                recordedAt: timestamp
            )
        )
        context.insert(
            PersonalConceptRevisionRecord(
                id: "revision-01",
                profileID: "profile-local",
                conceptID: "value",
                personalTitle: "내가 붙인 이름",
                explanation: "값에 대한 설명",
                examplesPayload: Data("[]".utf8),
                previousRevisionID: nil,
                evidenceActivityID: "activity-01",
                createdAt: timestamp
            )
        )
        context.insert(
            PersonalKnowledgeRelationRecord(
                id: "relation-01",
                profileID: "profile-local",
                sourceConceptID: "value",
                targetConceptID: "type",
                statement: "값에는 타입이 있다.",
                reason: "활동에서 확인했다.",
                evidenceActivityID: "activity-01",
                createdAt: timestamp
            )
        )

        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<LocalProfileRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<LearningProgressRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ActivityResponseRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<LearningEvidenceRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PersonalConceptRevisionRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PersonalKnowledgeRelationRecord>()) == 1)
    }

    @Test
    func inMemoryContainersDoNotShareState() throws {
        let firstContainer = try PersistenceContainerFactory.inMemory()
        let firstContext = ModelContext(firstContainer)
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)

        firstContext.insert(
            LocalProfileRecord(
                id: "profile-local",
                createdAt: timestamp,
                lastOpenedAt: timestamp
            )
        )
        try firstContext.save()

        let secondContainer = try PersistenceContainerFactory.inMemory()
        let secondContext = ModelContext(secondContainer)

        #expect(try secondContext.fetchCount(FetchDescriptor<LocalProfileRecord>()) == 0)
    }

    @Test
    func appAssemblyRetainsOneRootContainer() throws {
        let assembly = try AppAssembly.inMemory()
        let sceneContainer = assembly.modelContainer
        let dependencyContainer = assembly.modelContainer

        #expect(sceneContainer === dependencyContainer)
    }
}
