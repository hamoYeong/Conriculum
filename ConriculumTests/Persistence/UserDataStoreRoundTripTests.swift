import Foundation
import SwiftData
import Testing
@testable import Conriculum

@MainActor
struct UserDataStoreRoundTripTests {
    private let firstDate = Date(timeIntervalSince1970: 1_725_782_400)
    private let secondDate = Date(timeIntervalSince1970: 1_725_868_800)

    @Test
    func fileBackedRecordsRecoverAfterContainerRelaunch() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(
                path: "ConriculumRelaunch-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "Conriculum.store")
        let original = relaunchFixture(at: firstDate, suffix: "original")
        let updated = relaunchFixture(at: secondDate, suffix: "updated")

        let originalProfileID = try await writeRelaunchFixture(
            original,
            then: updated,
            storeURL: storeURL
        )
        let recoveredProfileID = try await verifyRelaunchFixture(
            updated,
            storeURL: storeURL
        )

        #expect(recoveredProfileID == originalProfileID)
    }

    @Test
    func learningRecordsRoundTripAndRecoverInANewClient() async throws {
        let environment = try PersistenceEnvironmentRegistry.makeInMemoryEnvironment()
        let firstClient = LearningRecordClient.live(store: environment.userDataStore)
        let originalProgress = LearningProgress(
            chapterID: "chapter-02",
            currentPageID: "chapter-02-page-01",
            completedPageIDs: [],
            updatedAt: firstDate
        )
        let originalResponse = ActivityResponse(
            id: "response-01",
            activityID: "activity-page-01-card-sorting",
            pageID: originalProgress.currentPageID,
            fields: [
                ActivityResponseField(key: "selected", values: ["String", "Int"])
            ],
            recordedAt: firstDate
        )

        try await firstClient.saveProgress(originalProgress)
        try await firstClient.saveResponse(originalResponse)

        var evidenceByKind: [LearningEvidenceKind: LearningEvidence] = [:]
        for (index, kind) in LearningEvidenceKind.allCases.enumerated() {
            let evidence = LearningEvidence(
                id: LearningEvidenceID(rawValue: "evidence-\(index)"),
                kind: kind,
                pageID: originalProgress.currentPageID,
                activityID: kind == .viewed ? nil : originalResponse.activityID,
                responseID: kind == .viewed ? nil : originalResponse.id,
                note: "\(kind.rawValue) evidence",
                recordedAt: firstDate.addingTimeInterval(Double(index))
            )
            evidenceByKind[kind] = evidence
            try await firstClient.saveEvidence(evidence)
        }

        let updatedProgress = LearningProgress(
            chapterID: originalProgress.chapterID,
            currentPageID: "chapter-02-page-02",
            completedPageIDs: [originalProgress.currentPageID],
            updatedAt: secondDate
        )
        let updatedResponse = ActivityResponse(
            id: originalResponse.id,
            activityID: originalResponse.activityID,
            pageID: originalResponse.pageID,
            fields: [
                ActivityResponseField(key: "selected", values: ["String"]),
                ActivityResponseField(key: "reason", values: ["텍스트 의미를 보존한다."]),
            ],
            recordedAt: secondDate
        )
        try await firstClient.saveProgress(updatedProgress)
        try await firstClient.saveResponse(updatedResponse)

        let relaunchedStore = UserDataStore(
            modelContainer: environment.modelContainer
        )
        let relaunchedClient = LearningRecordClient.live(store: relaunchedStore)
        let recoveredProgress = try await relaunchedClient.loadProgress(
            originalProgress.chapterID
        )
        let recoveredResponses = try await relaunchedClient.loadResponses(
            originalProgress.currentPageID
        )
        let recoveredEvidence = try await relaunchedClient.loadEvidence(
            originalProgress.currentPageID
        )

        #expect(recoveredProgress == updatedProgress)
        #expect(recoveredResponses == [updatedResponse])
        #expect(Set(recoveredEvidence.map(\.kind)) == Set(LearningEvidenceKind.allCases))
        #expect(recoveredEvidence.allSatisfy { evidenceByKind[$0.kind] == $0 })
    }

    @Test
    func personalKnowledgeCreatesUpdatesAndRecoversInANewClient() async throws {
        let environment = try PersistenceEnvironmentRegistry.makeInMemoryEnvironment()
        let firstClient = PersonalKnowledgeClient.live(store: environment.userDataStore)
        let originalRevision = PersonalConceptRevision(
            id: "revision-01",
            conceptID: "concept-value",
            personalTitle: "내가 이해한 값",
            explanation: "프로그램이 다루는 정보다.",
            examples: [
                PersonalExample(
                    id: "example-01",
                    text: "주문의 수량 2",
                    context: "주문"
                )
            ],
            previousRevisionID: nil,
            evidenceActivityID: "activity-page-07-personalization",
            createdAt: firstDate
        )
        let originalRelation = PersonalKnowledgeRelation(
            id: "personal-relation-01",
            sourceConceptID: "concept-value",
            targetConceptID: "concept-type",
            statement: "값은 타입을 가진다.",
            reason: "타입이 가능한 연산을 정하기 때문이다.",
            evidenceActivityID: "activity-page-07-create-relation",
            createdAt: firstDate
        )

        try await firstClient.saveRevision(originalRevision)
        try await firstClient.saveRelation(originalRelation)

        let updatedRevision = PersonalConceptRevision(
            id: originalRevision.id,
            conceptID: originalRevision.conceptID,
            personalTitle: "구체적인 정보 한 조각",
            explanation: "계산이나 판단의 대상이 되는 구체적인 정보다.",
            examples: originalRevision.examples,
            previousRevisionID: "revision-00",
            evidenceActivityID: originalRevision.evidenceActivityID,
            createdAt: secondDate
        )
        let updatedRelation = PersonalKnowledgeRelation(
            id: originalRelation.id,
            sourceConceptID: originalRelation.sourceConceptID,
            targetConceptID: originalRelation.targetConceptID,
            statement: "값의 타입은 가능한 연산의 범위를 정한다.",
            reason: "같은 표기라도 타입에 따라 의미와 연산이 달라질 수 있다.",
            evidenceActivityID: originalRelation.evidenceActivityID,
            createdAt: secondDate
        )
        try await firstClient.saveRevision(updatedRevision)
        try await firstClient.saveRelation(updatedRelation)

        let relaunchedStore = UserDataStore(
            modelContainer: environment.modelContainer
        )
        let relaunchedClient = PersonalKnowledgeClient.live(store: relaunchedStore)
        let recoveredRevisions = try await relaunchedClient.loadRevisions(
            originalRevision.conceptID
        )
        let recoveredRelationsFromSource = try await relaunchedClient.loadRelations(
            originalRelation.sourceConceptID
        )
        let recoveredRelationsFromTarget = try await relaunchedClient.loadRelations(
            originalRelation.targetConceptID
        )
        let recoveredAllRevisions = try await relaunchedClient.loadAllRevisions()
        let recoveredAllRelations = try await relaunchedClient.loadAllRelations()

        #expect(recoveredRevisions == [updatedRevision])
        #expect(recoveredRelationsFromSource == [updatedRelation])
        #expect(recoveredRelationsFromTarget == [updatedRelation])
        #expect(recoveredAllRevisions == [updatedRevision])
        #expect(recoveredAllRelations == [updatedRelation])
    }

    @Test
    func failedRelationSaveRollsBackAndPreservesTheLastSuccess() async throws {
        let modelContainer = try PersistenceContainerFactory.inMemory()
        let failure = SaveFailureController()
        let store = UserDataStore(
            modelContainer: modelContainer,
            saveContext: { context in
                if failure.shouldFail {
                    throw StubSaveError()
                }
                try context.save()
            }
        )
        let client = PersonalKnowledgeClient.live(store: store)
        let successfulRelation = PersonalKnowledgeRelation(
            id: "personal-relation-01",
            sourceConceptID: "concept-value",
            targetConceptID: "concept-type",
            statement: "값은 타입을 가진다.",
            reason: "타입이 연산 범위를 정한다.",
            evidenceActivityID: "activity-page-07-create-relation",
            createdAt: firstDate
        )

        try await client.saveRelation(successfulRelation)

        let rejectedUpdate = PersonalKnowledgeRelation(
            id: successfulRelation.id,
            sourceConceptID: successfulRelation.sourceConceptID,
            targetConceptID: successfulRelation.targetConceptID,
            statement: "저장되면 안 되는 변경",
            reason: "강제 실패를 검증한다.",
            evidenceActivityID: successfulRelation.evidenceActivityID,
            createdAt: secondDate
        )
        failure.shouldFail = true

        do {
            try await client.saveRelation(rejectedUpdate)
            Issue.record("강제로 실패시킨 relation 저장이 성공했다.")
        } catch let error as PersistenceClientError {
            guard case let .saveFailed(operation, _) = error else {
                Issue.record("예상하지 못한 persistence 오류: \(error)")
                return
            }
            #expect(operation == "saveRelation")
        } catch {
            Issue.record("식별할 수 없는 저장 오류: \(error)")
        }

        let relaunchedStore = UserDataStore(modelContainer: modelContainer)
        let relaunchedClient = PersonalKnowledgeClient.live(store: relaunchedStore)
        let recoveredRelations = try await relaunchedClient.loadRelations(
            successfulRelation.sourceConceptID
        )

        #expect(recoveredRelations == [successfulRelation])
    }

    @Test
    func failedRevisionSaveRollsBackAndPreservesTheLastSuccess() async throws {
        let modelContainer = try PersistenceContainerFactory.inMemory()
        let failure = SaveFailureController()
        let store = UserDataStore(
            modelContainer: modelContainer,
            saveContext: { context in
                if failure.shouldFail {
                    throw StubSaveError()
                }
                try context.save()
            }
        )
        let client = PersonalKnowledgeClient.live(store: store)
        let successfulRevision = PersonalConceptRevision(
            id: "personal-revision-01",
            conceptID: "concept-value",
            personalTitle: "내가 이해한 값",
            explanation: "프로그램이 직접 다룰 수 있게 정한 정보다.",
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: "activity-page01-choice",
            createdAt: firstDate
        )

        try await client.saveRevision(successfulRevision)

        let rejectedUpdate = PersonalConceptRevision(
            id: successfulRevision.id,
            conceptID: successfulRevision.conceptID,
            personalTitle: "저장되면 안 되는 이름",
            explanation: "강제 실패 뒤 복구되어야 하는 설명이다.",
            examples: [],
            previousRevisionID: successfulRevision.previousRevisionID,
            evidenceActivityID: successfulRevision.evidenceActivityID,
            createdAt: secondDate
        )
        failure.shouldFail = true

        do {
            try await client.saveRevision(rejectedUpdate)
            Issue.record("강제로 실패시킨 revision 저장이 성공했다.")
        } catch let error as PersistenceClientError {
            guard case let .saveFailed(operation, _) = error else {
                Issue.record("예상하지 못한 persistence 오류: \(error)")
                return
            }
            #expect(operation == "saveRevision")
        } catch {
            Issue.record("식별할 수 없는 저장 오류: \(error)")
        }

        let relaunchedStore = UserDataStore(modelContainer: modelContainer)
        let relaunchedClient = PersonalKnowledgeClient.live(
            store: relaunchedStore
        )
        let recoveredRevisions = try await relaunchedClient.loadRevisions(
            successfulRevision.conceptID
        )

        #expect(recoveredRevisions == [successfulRevision])
    }

    private func writeRelaunchFixture(
        _ original: RelaunchFixture,
        then updated: RelaunchFixture,
        storeURL: URL
    ) async throws -> LocalProfileID {
        let container = try fileBackedContainer(at: storeURL)
        let store = UserDataStore(modelContainer: container)
        let learningClient = LearningRecordClient.live(store: store)
        let knowledgeClient = PersonalKnowledgeClient.live(store: store)
        let profileID = try store.localProfileID()

        try await learningClient.saveProgress(original.progress)
        try await learningClient.saveResponse(original.response)
        try await learningClient.saveEvidence(original.evidence)
        try await knowledgeClient.saveRevision(original.revision)
        try await knowledgeClient.saveRelation(original.relation)

        try await learningClient.saveProgress(updated.progress)
        try await learningClient.saveResponse(updated.response)
        try await learningClient.saveEvidence(updated.evidence)
        try await knowledgeClient.saveRevision(updated.revision)
        try await knowledgeClient.saveRelation(updated.relation)

        return profileID
    }

    private func verifyRelaunchFixture(
        _ expected: RelaunchFixture,
        storeURL: URL
    ) async throws -> LocalProfileID {
        let container = try fileBackedContainer(at: storeURL)
        let store = UserDataStore(modelContainer: container)
        let learningClient = LearningRecordClient.live(store: store)
        let knowledgeClient = PersonalKnowledgeClient.live(store: store)
        let profileID = try store.localProfileID()

        #expect(
            try await learningClient.loadProgress(
                expected.progress.chapterID
            ) == expected.progress
        )
        #expect(
            try await learningClient.loadResponses(
                expected.response.pageID
            ) == [expected.response]
        )
        #expect(
            try await learningClient.loadEvidence(
                expected.evidence.pageID
            ) == [expected.evidence]
        )
        #expect(
            try await knowledgeClient.loadRevisions(
                expected.revision.conceptID
            ) == [expected.revision]
        )
        #expect(
            try await knowledgeClient.loadRelations(
                expected.relation.targetConceptID
            ) == [expected.relation]
        )

        return profileID
    }

    private func fileBackedContainer(at storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "ConriculumRelaunchTest",
            schema: ConriculumPersistenceSchema.schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: ConriculumPersistenceSchema.schema,
            configurations: [configuration]
        )
    }

    private func relaunchFixture(
        at timestamp: Date,
        suffix: String
    ) -> RelaunchFixture {
        let isUpdated = suffix == "updated"
        return RelaunchFixture(
            progress: LearningProgress(
                chapterID: "chapter-02",
                currentPageID: isUpdated
                    ? "chapter-02-page-02"
                    : "chapter-02-page-01",
                completedPageIDs: isUpdated
                    ? ["chapter-02-page-01"]
                    : [],
                updatedAt: timestamp
            ),
            response: ActivityResponse(
                id: "response-relaunch",
                activityID: "activity-page01-choice",
                pageID: "chapter-02-page-01",
                fields: [
                    ActivityResponseField(
                        key: "reason",
                        values: ["\(suffix) response"]
                    )
                ],
                recordedAt: timestamp
            ),
            evidence: LearningEvidence(
                id: "evidence-relaunch",
                kind: .reasoningExplanation,
                pageID: "chapter-02-page-01",
                activityID: "activity-page01-choice",
                responseID: "response-relaunch",
                note: "\(suffix) evidence",
                recordedAt: timestamp
            ),
            revision: PersonalConceptRevision(
                id: "revision-relaunch",
                conceptID: "concept-value",
                personalTitle: "\(suffix) value",
                explanation: "\(suffix) revision",
                examples: [],
                previousRevisionID: isUpdated
                    ? "revision-before-relaunch"
                    : nil,
                evidenceActivityID: "activity-page01-choice",
                createdAt: timestamp
            ),
            relation: PersonalKnowledgeRelation(
                id: "relation-relaunch",
                sourceConceptID: "concept-value",
                targetConceptID: "concept-type",
                statement: "\(suffix) relation",
                reason: "\(suffix) reason",
                evidenceActivityID: "activity-page01-choice",
                createdAt: timestamp
            )
        )
    }
}

private struct RelaunchFixture {
    let progress: LearningProgress
    let response: ActivityResponse
    let evidence: LearningEvidence
    let revision: PersonalConceptRevision
    let relation: PersonalKnowledgeRelation
}

@MainActor
private final class SaveFailureController {
    var shouldFail = false
}

private struct StubSaveError: Error {}
