import SwiftUI

enum BaseKnowledgeDetailLevel: Equatable, Sendable {
    /// 기존 학습 Inspector와 같은 정보량.
    case contextual
    /// 전체 지식 탐색기에서 판단 질문과 오해까지 펼친 정보량.
    case complete
}

/// 공용 Concept의 변경되지 않는 기준 지식을 표시한다.
struct BaseKnowledgeSection: View {
    let concept: KnowledgeConcept
    let usage: String?
    let detailLevel: BaseKnowledgeDetailLevel

    init(
        concept: KnowledgeConcept,
        usage: String? = nil,
        detailLevel: BaseKnowledgeDetailLevel = .contextual
    ) {
        self.concept = concept
        self.usage = usage
        self.detailLevel = detailLevel
    }

    var body: some View {
        KnowledgeSection(
            title: "기본 지식 · 변경되지 않음",
            systemImage: "book.closed",
            accent: .blue
        ) {
            VStack(alignment: .leading, spacing: 16) {
                KnowledgeDefinitionBlock(text: concept.definition)

                if let usage {
                    KnowledgeLabeledText(
                        title: "이 페이지에서",
                        text: usage,
                        systemImage: "arrow.turn.down.right"
                    )
                }

                KnowledgeQuestionBlock(
                    question: concept.essentialQuestion
                )

                if detailLevel == .complete,
                   !concept.judgmentQuestions.isEmpty
                {
                    KnowledgeItemList(
                        title: "판단 질문",
                        systemImage: "checklist",
                        items: concept.judgmentQuestions,
                        style: .numbered
                    )
                }

                if !concept.examples.isEmpty {
                    KnowledgeItemList(
                        title: "기본 예시",
                        systemImage: "list.bullet",
                        items: concept.examples,
                        style: .example
                    )
                }

                if detailLevel == .complete,
                   !concept.misconceptions.isEmpty
                {
                    KnowledgeItemList(
                        title: "자주 생기는 오해",
                        systemImage: "exclamationmark.bubble",
                        items: concept.misconceptions,
                        style: .caution
                    )
                }
            }
        }
    }
}
