import Foundation
import Testing
@testable import Conriculum

@MainActor
struct HomeSnapshotComposerTests {
    @Test
    func emptyFixtureHasNoInventedProgressOrCompletion() {
        let snapshot = HomePreviewFixtures.empty

        #expect(snapshot.source == .empty)
        #expect(snapshot.chapter.resumePageID == nil)
        #expect(snapshot.chapter.lastPage == nil)
        #expect(snapshot.lastActivity == nil)
        #expect(snapshot.evidence.count == LearningEvidenceKind.allCases.count)
        #expect(snapshot.evidence.allSatisfy { $0.count == 0 && $0.latestAt == nil })
        #expect(snapshot.knowledgeChanges.confirmed.isEmpty)
        #expect(snapshot.knowledgeChanges.pending.isEmpty)
    }

    @Test
    func mockFixtureDisclosesThatItIsNotStoredLearningData() {
        let snapshot = HomePreviewFixtures.mock

        guard case let .previewFixture(disclosure) = snapshot.source else {
            Issue.record("mock fixture가 preview 출처를 표시하지 않는다.")
            return
        }
        #expect(disclosure.contains("실제 저장 기록이 아닙니다"))
        #expect(snapshot.chapter.resumePageID == "chapter-02-page-03")
        #expect(snapshot.evidence.contains {
            $0.kind == .reasoningExplanation && $0.count == 2
        })
        guard let firstChange = snapshot.knowledgeChanges.confirmed.first,
              case .revision = firstChange
        else {
            Issue.record("populated mock fixture에 최근 개인 지식이 없다.")
            return
        }
        #expect(snapshot.knowledgeChanges.pending.count == 1)
    }

    @Test
    func recordedValuesOverrideTheMockPlaceholder() throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let page = try #require(chapter.page(id: "chapter-02-page-03"))
        let firstDate = Date(timeIntervalSince1970: 1_725_782_400)
        let secondDate = firstDate.addingTimeInterval(60)
        let response = ActivityResponse(
            id: "recorded-response",
            activityID: "activity-page03-choice",
            pageID: page.id,
            fields: [ActivityResponseField(key: "reason", values: ["실제 응답"])],
            recordedAt: firstDate
        )
        let evidence = LearningEvidence(
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

        let snapshot = HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: LearningProgress(
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

        #expect(snapshot.source == .recorded)
        #expect(snapshot.chapter.resumePageID == page.id)
        #expect(snapshot.chapter.lastPage?.title == page.title)
        #expect(snapshot.lastActivity?.id == response.activityID)
        #expect(snapshot.lastActivity?.occurredAt == secondDate)
        #expect(snapshot.evidence.first {
            $0.kind == .independentSuccess
        }?.count == 1)
        #expect(snapshot.evidence.first {
            $0.kind == .reasoningExplanation
        }?.count == 0)
        guard let firstChange = snapshot.knowledgeChanges.confirmed.first,
              case let .revision(summary) = firstChange
        else {
            Issue.record("저장된 revision이 Home snapshot에 반영되지 않았다.")
            return
        }
        #expect(summary.id == revision.id)
        #expect(summary.personalTitle == revision.personalTitle)
        #expect(summary.explanation == revision.explanation)
    }

    @Test
    func mockPlaceholderIsUsedOnlyWhenStoredRecordsAreEmpty() throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)

        let snapshot = HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: nil,
            responses: [],
            evidence: [],
            revisions: [],
            placeholder: .mock
        )

        #expect(snapshot == .mock)
    }

    @Test
    func emptyCompositionUsesContentBackedMessages() throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)

        let snapshot = HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: nil,
            responses: [],
            evidence: [],
            revisions: []
        )

        #expect(snapshot.source == .empty)
        #expect(snapshot.chapter.resumePageID == nil)
        #expect(snapshot.chapter.accessNote?.contains("미리보기 상태") == true)
        #expect(snapshot.knowledgeChanges.confirmed.isEmpty)
        #expect(snapshot.knowledgeChanges.pending.isEmpty)
        #expect(
            snapshot.knowledgeChangesEmptyStateMessage
                == chapter.overview.knowledgeContext.emptyStateMessage
        )
    }

    @Test
    func confirmedRelationsAndPendingCandidatesStayInSeparateSections() throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(Chapter.self, from: .chapter02)
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
        let review = KnowledgePersonalizationReview(
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

        let snapshot = HomeSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            progress: nil,
            responses: [],
            evidence: [],
            revisions: [],
            relations: [relation],
            pendingPersonalizationReviews: [review]
        )

        #expect(snapshot.source == .recorded)
        #expect(snapshot.knowledgeChanges.confirmed.count == 1)
        #expect(snapshot.knowledgeChanges.pending.count == 1)
        guard let firstChange = snapshot.knowledgeChanges.confirmed.first,
              case let .relation(summary) = firstChange
        else {
            Issue.record("확인된 연결이 저장 변화 영역에 없다.")
            return
        }
        #expect(summary.id == relation.id)
        #expect(snapshot.knowledgeChanges.pending.first?.id == review.id)
    }
}

private extension HomeSnapshot {
    static var mock: Self { HomePreviewFixtures.mock }
}
