import Foundation
import Testing

@testable import Conriculum

// MARK: - 학습 체계 Domain의 핵심 계약을 호출로 확인

struct V1CurriculumModelsTests {
    /// StableID가 JSON 객체가 아니라 단일 문자열로 왕복되는지 확인한다.
    @Test
    func stableIDsEncodeAsSingleJSONStrings() throws {
        let id: LearningPageID = "chapter-02-page-01"

        let data = try JSONEncoder().encode(id)
        let decoded = try JSONDecoder().decode(LearningPageID.self, from: data)

        #expect(String(decoding: data, as: UTF8.self) == #""chapter-02-page-01""#)
        #expect(decoded == id)
    }

    /// 배열 위치가 뒤섞여도 ID로 찾고 `order`로 진도를 정렬하는지 확인한다.
    @Test
    func pageLookupUsesStableIDInsteadOfArrayPosition() {
        let page01 = makePage(id: "chapter-02-page-01", order: 1)
        let page02 = makePage(id: "chapter-02-page-02", order: 2)
        let chapter = makeChapter(pages: [page02, page01])

        #expect(chapter.page(id: "chapter-02-page-01") == page01)
        #expect(chapter.progressPageIDs == ["chapter-02-page-01", "chapter-02-page-02"])
    }

    /// overview는 전체 탐색에는 포함되지만 진도 분모에는 들어가지 않는지 확인한다.
    @Test
    func overviewIsExcludedFromProgress() {
        let chapter = makeChapter(
            pages: [
                makePage(id: "chapter-02-page-01", order: 1),
                makePage(id: "chapter-02-page-02", order: 2),
            ]
        )

        #expect(chapter.allPages.count == 3)
        #expect(chapter.progressDenominator == 2)
        #expect(chapter.progressPageIDs.contains("chapter-02-overview") == false)
    }

    /// Curriculum 값이 UI actor에 묶이지 않고 concurrency 경계를 넘는 순수 값인지 확인한다.
    @Test
    func curriculumValuesAreSendable() {
        let chapter = makeChapter(pages: [])

        assertSendable(chapter)
        assertSendable(chapter.overview.knowledgeContext)
    }

    // 아래 helper는 위 계약을 드러내기 위한 최소 fixture다. assertion을 이해한 뒤 읽는다.
    private func makeChapter(pages: [V1LearningPage]) -> V1Chapter {
        V1Chapter(
            id: "chapter-02",
            stageID: "stage-01",
            order: 2,
            title: "정보를 값과 타입으로 표현하기",
            summary: "현실의 정보를 이름 붙은 Swift 값으로 선언한다.",
            overview: makePage(
                id: "chapter-02-overview",
                kind: .overview,
                order: nil
            ),
            pages: pages
        )
    }

    private func makePage(
        id: LearningPageID,
        kind: V1LearningPage.Kind = .lesson,
        order: Int?
    ) -> V1LearningPage {
        V1LearningPage(
            id: id,
            kind: kind,
            order: order,
            title: id.rawValue,
            goal: "학습 목표",
            sections: [],
            activities: [],
            knowledgeLinks: [],
            knowledgeContext: V1PageKnowledgeContext(
                currentlyUsedConceptIDs: [],
                currentlyUsedSummary: "",
                changedKnowledgeSummary: "",
                nearbyKnowledge: [],
                refreshTriggers: [],
                emptyStateMessage: "아직 확인해 반영한 지식이 없다.",
                focusModeSummary: "현재 개념만 표시한다."
            ),
            navigation: V1LearningPageNavigation(previous: nil, next: nil)
        )
    }
}

private func assertSendable<Value: Sendable>(_ value: Value) {}

// MARK: - 다음 읽기: Conriculum/Domain/Knowledge/KnowledgeModels.swift
