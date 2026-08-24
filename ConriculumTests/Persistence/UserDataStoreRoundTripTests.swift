import Foundation
import SwiftData
import Testing
@testable import Conriculum

@MainActor
struct UserDataStoreRoundTripTests {
    private let firstDate = Date(timeIntervalSince1970: 1_725_782_400)
    private let secondDate = Date(timeIntervalSince1970: 1_725_868_800)

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

        #expect(recoveredRevisions == [updatedRevision])
        #expect(recoveredRelationsFromSource == [updatedRelation])
        #expect(recoveredRelationsFromTarget == [updatedRelation])
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
}

@MainActor
private final class SaveFailureController {
    var shouldFail = false
}

private struct StubSaveError: Error {}
