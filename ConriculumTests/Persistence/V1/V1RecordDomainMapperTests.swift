import Foundation
import Testing
@testable import Conriculum

@MainActor
struct V1RecordDomainMapperTests {
    private let profileID: LocalProfileID = "profile-local"
    private let firstDate = Date(timeIntervalSince1970: 1_725_782_400)
    private let secondDate = Date(timeIntervalSince1970: 1_725_868_800)

    @Test
    func localProfileRoundTripsAndUpdates() throws {
        let profile = V1LocalProfile(
            id: profileID,
            createdAt: firstDate,
            lastOpenedAt: firstDate
        )
        let record = try LocalProfileRecord(domainValue: profile)

        #expect(try record.domainValue() == profile)

        let updatedProfile = V1LocalProfile(
            id: profileID,
            createdAt: firstDate,
            lastOpenedAt: secondDate
        )
        try record.update(from: updatedProfile)

        #expect(try record.domainValue() == updatedProfile)
    }

    @Test
    func learningRecordsRoundTripAndUpdate() throws {
        let progress = V1LearningProgress(
            chapterID: "chapter-02",
            currentPageID: "page-02-01",
            completedPageIDs: ["page-02-00"],
            updatedAt: firstDate
        )
        let progressRecord = try LearningProgressRecord(
            profileID: profileID,
            domainValue: progress
        )

        #expect(try progressRecord.domainValue(profileID: profileID) == progress)

        let updatedProgress = V1LearningProgress(
            chapterID: progress.chapterID,
            currentPageID: "page-02-02",
            completedPageIDs: ["page-02-00", "page-02-01"],
            updatedAt: secondDate
        )
        try progressRecord.update(from: updatedProgress, profileID: profileID)
        #expect(try progressRecord.domainValue(profileID: profileID) == updatedProgress)

        let response = V1ActivityResponse(
            id: "response-01",
            activityID: "activity-01",
            pageID: "page-02-01",
            fields: [
                V1ActivityResponseField(key: "selected", values: ["String", "Bool"]),
                V1ActivityResponseField(key: "reason", values: ["의미에 맞기 때문이다."]),
            ],
            recordedAt: firstDate
        )
        let responseRecord = try ActivityResponseRecord(
            profileID: profileID,
            domainValue: response
        )

        #expect(try responseRecord.domainValue(profileID: profileID) == response)

        let updatedResponse = V1ActivityResponse(
            id: response.id,
            activityID: response.activityID,
            pageID: response.pageID,
            fields: [V1ActivityResponseField(key: "selected", values: ["String"])],
            recordedAt: secondDate
        )
        try responseRecord.update(from: updatedResponse, profileID: profileID)
        #expect(try responseRecord.domainValue(profileID: profileID) == updatedResponse)

        let evidence = V1LearningEvidence(
            id: "evidence-01",
            kind: .reasoningExplanation,
            pageID: response.pageID,
            activityID: response.activityID,
            responseID: response.id,
            note: "타입 선택 근거를 설명했다.",
            recordedAt: firstDate
        )
        let evidenceRecord = try LearningEvidenceRecord(
            profileID: profileID,
            domainValue: evidence
        )

        #expect(try evidenceRecord.domainValue(profileID: profileID) == evidence)

        let updatedEvidence = V1LearningEvidence(
            id: evidence.id,
            kind: .independentSuccess,
            pageID: evidence.pageID,
            activityID: evidence.activityID,
            responseID: evidence.responseID,
            note: "도움 없이 완료했다.",
            recordedAt: secondDate
        )
        try evidenceRecord.update(from: updatedEvidence, profileID: profileID)
        #expect(try evidenceRecord.domainValue(profileID: profileID) == updatedEvidence)
    }

    @Test
    func personalKnowledgeRecordsRoundTripAndUpdate() throws {
        let revision = PersonalConceptRevision(
            id: "revision-01",
            conceptID: "concept-value",
            personalTitle: "내가 이해한 값",
            explanation: "프로그램이 직접 다루는 한 조각의 정보다.",
            examples: [
                PersonalExample(
                    id: "example-01",
                    text: "장바구니 수량 2",
                    context: "주문"
                )
            ],
            previousRevisionID: nil,
            evidenceActivityID: "activity-01",
            createdAt: firstDate
        )
        let revisionRecord = try PersonalConceptRevisionRecord(
            profileID: profileID,
            domainValue: revision
        )

        #expect(try revisionRecord.domainValue(profileID: profileID) == revision)

        let updatedRevision = PersonalConceptRevision(
            id: revision.id,
            conceptID: revision.conceptID,
            personalTitle: "정보 한 조각",
            explanation: "계산과 판단의 대상이 되는 구체적인 정보다.",
            examples: revision.examples,
            previousRevisionID: "revision-00",
            evidenceActivityID: revision.evidenceActivityID,
            createdAt: secondDate
        )
        try revisionRecord.update(from: updatedRevision, profileID: profileID)
        #expect(try revisionRecord.domainValue(profileID: profileID) == updatedRevision)

        let relation = PersonalKnowledgeRelation(
            id: "relation-01",
            sourceConceptID: "concept-value",
            targetConceptID: "concept-type",
            statement: "모든 값은 타입을 가진다.",
            reason: "가능한 연산을 타입이 제한하기 때문이다.",
            evidenceActivityID: "activity-02",
            createdAt: firstDate
        )
        let relationRecord = try PersonalKnowledgeRelationRecord(
            profileID: profileID,
            domainValue: relation
        )

        #expect(try relationRecord.domainValue(profileID: profileID) == relation)

        let updatedRelation = PersonalKnowledgeRelation(
            id: relation.id,
            sourceConceptID: "concept-string",
            targetConceptID: relation.targetConceptID,
            statement: "String은 텍스트 값의 타입이다.",
            reason: "텍스트 연산의 범위를 정하기 때문이다.",
            evidenceActivityID: relation.evidenceActivityID,
            createdAt: secondDate
        )
        try relationRecord.update(from: updatedRelation, profileID: profileID)
        #expect(try relationRecord.domainValue(profileID: profileID) == updatedRelation)
    }

    @Test
    func corruptPayloadAndUnsupportedEvidenceKindAreIdentifiable() {
        let responseRecord = ActivityResponseRecord(
            id: "response-01",
            profileID: profileID.rawValue,
            activityID: "activity-01",
            pageID: "page-02-01",
            fieldsPayload: Data("not-json".utf8),
            recordedAt: firstDate
        )
        expectInvalidStoredData(
            record: "ActivityResponseRecord",
            fieldPath: "fieldsPayload"
        ) {
            _ = try responseRecord.domainValue(profileID: profileID)
        }

        let evidenceRecord = LearningEvidenceRecord(
            id: "evidence-01",
            profileID: profileID.rawValue,
            kindRawValue: "future-unsupported-kind",
            pageID: "page-02-01",
            activityID: nil,
            responseID: nil,
            note: nil,
            recordedAt: firstDate
        )
        expectInvalidStoredData(
            record: "LearningEvidenceRecord",
            fieldPath: "kindRawValue"
        ) {
            _ = try evidenceRecord.domainValue(profileID: profileID)
        }
    }

    @Test
    func invalidRelationAndReferencesAreRejected() {
        let relationRecord = PersonalKnowledgeRelationRecord(
            id: "relation-01",
            profileID: profileID.rawValue,
            sourceConceptID: "concept-value",
            targetConceptID: "concept-value",
            statement: "자기 자신을 연결한다.",
            reason: "잘못 저장된 관계다.",
            evidenceActivityID: "activity-01",
            createdAt: firstDate
        )
        expectInvalidStoredData(
            record: "PersonalKnowledgeRelationRecord",
            fieldPath: "targetConceptID"
        ) {
            _ = try relationRecord.domainValue(profileID: profileID)
        }

        let revisionRecord = PersonalConceptRevisionRecord(
            id: "revision-01",
            profileID: profileID.rawValue,
            conceptID: "concept-value",
            personalTitle: nil,
            explanation: "잘못 저장된 revision이다.",
            examplesPayload: Data("[]".utf8),
            previousRevisionID: "revision-01",
            evidenceActivityID: "activity-01",
            createdAt: firstDate
        )
        expectInvalidStoredData(
            record: "PersonalConceptRevisionRecord",
            fieldPath: "previousRevisionID"
        ) {
            _ = try revisionRecord.domainValue(profileID: profileID)
        }

        let evidenceRecord = LearningEvidenceRecord(
            id: "evidence-01",
            profileID: profileID.rawValue,
            kindRawValue: V1LearningEvidenceKind.activityAttempt.rawValue,
            pageID: "page-02-01",
            activityID: nil,
            responseID: "response-01",
            note: nil,
            recordedAt: firstDate
        )
        expectInvalidStoredData(
            record: "LearningEvidenceRecord",
            fieldPath: "responseID"
        ) {
            _ = try evidenceRecord.domainValue(profileID: profileID)
        }
    }

    private func expectInvalidStoredData(
        record expectedRecord: String,
        fieldPath expectedFieldPath: String,
        operation: () throws -> Void
    ) {
        do {
            try operation()
            Issue.record("잘못된 저장 데이터가 Domain 값으로 변환되었다.")
        } catch let error as V1PersistenceClientError {
            guard case let .invalidStoredData(record, fieldPath, _) = error else {
                Issue.record("예상하지 못한 persistence 오류: \(error)")
                return
            }
            #expect(record == expectedRecord)
            #expect(fieldPath == expectedFieldPath)
        } catch {
            Issue.record("예상하지 못한 오류: \(error)")
        }
    }
}
