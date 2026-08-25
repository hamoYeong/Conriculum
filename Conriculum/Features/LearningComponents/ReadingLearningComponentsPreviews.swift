import SwiftUI

private enum ReadingComponentPreviewFixtures {
    static let tags: [LearningSectionTag] = [
        .knowledgeRecall,
        .situation,
        .comparison,
        .definition,
        .decisionCriteria,
        .codeExplanation,
        .processGuide,
    ]

    static var sections: [LearningSection] {
        guard let chapter = try? ContentResourceDecoder().decode(
            Chapter.self,
            from: .chapter02
        ) else { return [] }

        let allSections = chapter.allPages.flatMap(\.sections)
        return tags.compactMap { tag in
            allSections.first { $0.content.tag == tag }
        }
    }
}

private struct ReadingLearningComponentsPreview: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(ReadingComponentPreviewFixtures.sections, id: \.id) {
                    section in
                    component(for: section.content)
                }
            }
            .frame(maxWidth: 760)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func component(
        for content: LearningSectionContent
    ) -> some View {
        switch content {
        case let .knowledgeRecall(payload):
            KnowledgeRecallComponent(content: payload)
        case let .situation(payload):
            SituationComponent(content: payload)
        case let .comparison(payload):
            ComparisonComponent(content: payload)
        case let .definition(payload):
            DefinitionComponent(content: payload)
        case let .decisionCriteria(payload):
            DecisionCriteriaComponent(content: payload)
        case let .codeExplanation(payload):
            CodeExplanationComponent(content: payload)
        case let .processGuide(payload):
            ProcessGuideComponent(content: payload)
        default:
            EmptyView()
        }
    }
}

#Preview("읽기와 관찰 · Chapter 2") {
    ReadingLearningComponentsPreview()
        .frame(width: 820, height: 1_000)
}

#Preview("읽기와 관찰 · 큰 텍스트") {
    ReadingLearningComponentsPreview()
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(width: 820, height: 1_000)
}
