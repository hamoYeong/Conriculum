import Testing

@testable import Conriculum

@MainActor
struct HomePresentationTests {
    @Test
    func evidenceKindsHaveStableKoreanLabelsAndSymbols() {
        let presentations = V1LearningEvidenceKind.allCases.map(
            V1HomeEvidencePresentation.init(kind:)
        )

        #expect(presentations.map(\.title) == [
            "열람",
            "활동 시도",
            "도움으로 성공",
            "독립 성공",
            "판단 설명",
            "개념 연결",
        ])
        #expect(presentations.allSatisfy { $0.systemImage.isEmpty == false })
        #expect(Set(presentations.map(\.systemImage)).count == presentations.count)
    }

    @Test
    func chapterActionDistinguishesStartFromResume() {
        let empty = V1HomePreviewFixtures.empty.chapter
        let populated = V1HomePreviewFixtures.mock.chapter

        #expect(empty.primaryActionTitle == "챕터 시작하기")
        #expect(empty.primaryActionAccessibilityHint.contains("개요"))
        #expect(populated.primaryActionTitle == "챕터 이어하기")
        #expect(populated.primaryActionAccessibilityHint.contains("마지막"))
    }
}
