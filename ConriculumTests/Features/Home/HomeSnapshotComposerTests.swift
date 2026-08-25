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
        guard case .empty = snapshot.knowledgeChange else {
            Issue.record("empty fixture가 개인 지식 변경을 만들어 냈다.")
            return
        }
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
        guard case .recentRevision = snapshot.knowledgeChange else {
            Issue.record("populated mock fixture에 최근 개인 지식이 없다.")
            return
        }
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
        guard case let .recentRevision(summary) = snapshot.knowledgeChange else {
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
        #expect(
            snapshot.knowledgeChange == .empty(
                message: chapter.overview.knowledgeContext.emptyStateMessage
            )
        )
    }
}

private extension HomeSnapshot {
    static var mock: Self { HomePreviewFixtures.mock }
}
