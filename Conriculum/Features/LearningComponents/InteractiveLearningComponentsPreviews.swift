import SwiftUI

private enum InteractiveComponentPreviewFixtures {
    static let tags: [LearningSectionTag] = [
        .learningCompass,
        .cardSorting,
        .matching,
        .choiceWithReason,
        .fillInBlank,
        .codeAssembly,
        .freeResponse,
        .recallCheck,
        .semanticChunkReading,
        .learningClosure,
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

private struct StatefulInteractiveComponentPreview: View {
    let section: LearningSection
    @State private var fields: [ActivityResponseField] = []

    private var activity: LearningActivityInput {
        LearningActivityInput(
            activityID: section.activityID ?? "preview-activity",
            fields: fields
        ) { _, updatedFields in
            fields = updatedFields
        }
    }

    var body: some View {
        component
    }

    @ViewBuilder
    private var component: some View {
        switch section.content {
        case let .learningCompass(payload):
            LearningCompassComponent(content: payload, activity: activity)
        case let .cardSorting(payload):
            CardSortingComponent(content: payload, activity: activity)
        case let .matching(payload):
            MatchingComponent(content: payload, activity: activity)
        case let .choiceWithReason(payload):
            ChoiceWithReasonComponent(content: payload, activity: activity)
        case let .fillInBlank(payload):
            FillInBlankComponent(content: payload, activity: activity)
        case let .codeAssembly(payload):
            CodeAssemblyComponent(content: payload, activity: activity)
        case let .freeResponse(payload):
            FreeResponseComponent(content: payload, activity: activity)
        case let .recallCheck(payload):
            RecallCheckComponent(content: payload, activity: activity)
        case let .semanticChunkReading(payload):
            SemanticChunkReadingComponent(
                content: payload,
                activity: activity
            )
        case let .learningClosure(payload):
            LearningClosureComponent(content: payload, activity: activity)
        default:
            EmptyView()
        }
    }
}

private struct InteractiveLearningComponentsPreview: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(InteractiveComponentPreviewFixtures.sections, id: \.id) {
                    section in
                    StatefulInteractiveComponentPreview(section: section)
                }
            }
            .frame(maxWidth: 760)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("사용자 작업 · Chapter 2") {
    InteractiveLearningComponentsPreview()
        .frame(width: 820, height: 1_000)
}

#Preview("사용자 작업 · 큰 텍스트") {
    InteractiveLearningComponentsPreview()
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(width: 820, height: 1_000)
}
