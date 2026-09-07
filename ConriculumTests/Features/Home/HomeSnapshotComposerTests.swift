import Foundation
import Testing
@testable import Conriculum

@MainActor
struct HomeSnapshotComposerTests {
    @Test
    func emptyFixtureHasNoInventedProgressOrCompletion() {
        let v1Snapshot = V1HomePreviewFixtures.empty

        #expect(v1Snapshot.source == .empty)
        #expect(v1Snapshot.chapter.resumePageID == nil)
        #expect(v1Snapshot.chapter.lastPage == nil)
        #expect(v1Snapshot.lastActivity == nil)
        #expect(v1Snapshot.evidence.count == V1LearningEvidenceKind.allCases.count)
        #expect(v1Snapshot.evidence.allSatisfy { $0.count == 0 && $0.latestAt == nil })
        #expect(v1Snapshot.knowledgeChanges.confirmed.isEmpty)
        #expect(v1Snapshot.knowledgeChanges.pending.isEmpty)
    }

    @Test
    func mockFixtureDisclosesThatItIsNotStoredLearningData() {
        let v1Snapshot = V1HomePreviewFixtures.mock

        guard case let .previewFixture(disclosure) = v1Snapshot.source else {
            Issue.record("mock fixture가 preview 출처를 표시하지 않는다.")
            return
        }
        #expect(disclosure.contains("실제 저장 기록이 아닙니다"))
        #expect(v1Snapshot.chapter.resumePageID == "chapter-02-page-03")
        #expect(v1Snapshot.evidence.contains {
            $0.kind == .reasoningExplanation && $0.count == 2
        })
        guard let firstChange = v1Snapshot.knowledgeChanges.confirmed.first,
              case .revision = firstChange
        else {
            Issue.record("populated mock fixture에 최근 개인 지식이 없다.")
            return
        }
        #expect(v1Snapshot.knowledgeChanges.pending.count == 1)
    }

    @Test
    func recordedValuesOverrideTheMockPlaceholder() throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(V1Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let page = try #require(chapter.page(id: "chapter-02-page-03"))
        let firstDate = Date(timeIntervalSince1970: 1_725_782_400)
        let secondDate = firstDate.addingTimeInterval(60)
        let response = V1ActivityResponse(
            id: "recorded-response",
            activityID: "activity-page03-choice",
            pageID: page.id,
            fields: [V1ActivityResponseField(key: "reason", values: ["실제 응답"])],
            recordedAt: firstDate
        )
        let evidence = V1LearningEvidence(
            id: "recorded-evidence",
            kind: .independentSuccess,
            pageID: page.id,
            activityID: response.activityID,
            responseID: response.id,
            note: "저장된 독립 성공",
            recordedAt: secondDate
        )
        let revision = PersonalConceptRevision(
            id: "recorded-revision",
            conceptID: "concept-type-selection",
            personalTitle: "저장된 나의 타입 선택",
            explanation: "실제 저장된 설명",
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: response.activityID,
            createdAt: secondDate
        )

        let v1Snapshot = V1HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: V1LearningProgress(
                chapterID: chapter.id,
                currentPageID: page.id,
                completedPageIDs: ["chapter-02-page-01", "chapter-02-page-02"],
                updatedAt: secondDate
            ),
            responses: [response],
            evidence: [evidence],
            revisions: [revision],
            placeholder: .mock
        )

        #expect(v1Snapshot.source == .recorded)
        #expect(v1Snapshot.chapter.resumePageID == page.id)
        #expect(v1Snapshot.chapter.lastPage?.title == page.title)
        #expect(v1Snapshot.lastActivity?.id == response.activityID)
        #expect(v1Snapshot.lastActivity?.occurredAt == secondDate)
        #expect(v1Snapshot.evidence.first {
            $0.kind == .independentSuccess
        }?.count == 1)
        #expect(v1Snapshot.evidence.first {
            $0.kind == .reasoningExplanation
        }?.count == 0)
        guard let firstChange = v1Snapshot.knowledgeChanges.confirmed.first,
              case let .revision(summary) = firstChange
        else {
            Issue.record("저장된 revision이 Home v1Snapshot에 반영되지 않았다.")
            return
        }
        #expect(summary.id == revision.id)
        #expect(summary.personalTitle == revision.personalTitle)
        #expect(summary.explanation == revision.explanation)
    }

    @Test
    func mockPlaceholderIsUsedOnlyWhenStoredRecordsAreEmpty() throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(V1Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)

        let v1Snapshot = V1HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: nil,
            responses: [],
            evidence: [],
            revisions: [],
            placeholder: .mock
        )

        #expect(v1Snapshot == .mock)
    }

    @Test
    func emptyCompositionUsesContentBackedMessages() throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(V1Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)

        let v1Snapshot = V1HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: nil,
            responses: [],
            evidence: [],
            revisions: []
        )

        #expect(v1Snapshot.source == .empty)
        #expect(v1Snapshot.chapter.resumePageID == nil)
        #expect(v1Snapshot.chapter.accessNote == nil)
        #expect(v1Snapshot.knowledgeChanges.confirmed.isEmpty)
        #expect(v1Snapshot.knowledgeChanges.pending.isEmpty)
        #expect(
            v1Snapshot.knowledgeChangesEmptyStateMessage
                == chapter.overview.knowledgeContext.emptyStateMessage
        )
    }

    @Test
    func confirmedRelationsAndPendingCandidatesStayInSeparateSections() throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(V1Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let relation = PersonalKnowledgeRelation(
            id: "relation-home",
            sourceConceptID: "concept-value",
            targetConceptID: "concept-type",
            statement: "값은 타입이 허용하는 사용과 연결된다.",
            reason: "타입이 가능한 연산을 정하기 때문이다.",
            evidenceActivityID: "activity-page02-matching",
            createdAt: timestamp
        )
        let review = V1KnowledgePersonalizationReview(
            candidate: KnowledgePersonalizationCandidate(
                id: "candidate-home",
                kind: .conceptRevision,
                conceptIDs: ["concept-value", "concept-type"],
                draft: "값과 가능한 사용을 함께 설명한다.",
                evidenceActivityID: "activity-page02-matching",
                createdAt: timestamp.addingTimeInterval(60)
            ),
            targetConceptID: "concept-value",
            activityID: "activity-page02-promotion",
            confirmationQuestion: "이 설명을 나의 지식으로 반영할까?",
            savedFields: ["나의 설명", "근거 활동 ID"]
        )

        let v1Snapshot = V1HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: nil,
            responses: [],
            evidence: [],
            revisions: [],
            relations: [relation],
            pendingPersonalizationReviews: [review]
        )

        #expect(v1Snapshot.source == .recorded)
        #expect(v1Snapshot.knowledgeChanges.confirmed.count == 1)
        #expect(v1Snapshot.knowledgeChanges.pending.count == 1)
        guard let firstChange = v1Snapshot.knowledgeChanges.confirmed.first,
              case let .relation(summary) = firstChange
        else {
            Issue.record("확인된 연결이 저장 변화 영역에 없다.")
            return
        }
        #expect(summary.id == relation.id)
        #expect(v1Snapshot.knowledgeChanges.pending.first?.id == review.id)
    }
}

private extension V1HomeSnapshot {
    static var mock: Self { V1HomePreviewFixtures.mock }
}
