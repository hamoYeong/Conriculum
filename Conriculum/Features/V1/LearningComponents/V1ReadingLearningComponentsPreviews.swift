import SwiftUI

private enum ReadingComponentPreviewFixtures {
    static let tags: [V1LearningSectionTag] = [
        .situation,
        .comparison,
        .definition,
        .decisionCriteria,
        .codeExplanation,
        .processGuide,
    ]

    static var sections: [V1LearningSection] {
        guard let chapter = try? ContentResourceDecoder().decode(
            V1Chapter.self,
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
        for content: V1LearningSectionContent
    ) -> some View {
        switch content {
        case let .situation(payload):
            V1SituationComponent(content: payload)
        case let .comparison(payload):
            V1ComparisonComponent(content: payload)
        case let .definition(payload):
            V1DefinitionComponent(content: payload)
        case let .decisionCriteria(payload):
            V1DecisionCriteriaComponent(content: payload)
        case let .codeExplanation(payload):
            V1CodeExplanationComponent(content: payload)
        case let .processGuide(payload):
            V1ProcessGuideComponent(content: payload)
        default:
            EmptyView()
        }
    }
}

#Preview("읽기와 관찰 · V1Chapter 2") {
    ReadingLearningComponentsPreview()
        .frame(width: 820, height: 1_000)
}

#Preview("읽기와 관찰 · 큰 텍스트") {
    ReadingLearningComponentsPreview()
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(width: 820, height: 1_000)
}
