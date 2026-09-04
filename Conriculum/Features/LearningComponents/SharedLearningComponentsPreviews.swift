import SwiftUI

private enum SharedComponentPreviewFixtures {
    static let tags: [LearningSectionTag] = [
        .knowledgeLink,
        .enrichmentTask,
        .personalKnowledgePromotion,
        .personalKnowledgeRelation,
        .knowledgeChangeSummary,
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

    static var conceptNames: KnowledgeConceptNames {
        guard let catalog = try? ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        ) else { return KnowledgeConceptNames(titles: [:]) }
        return KnowledgeConceptNames(catalog: catalog)
    }
}

private struct StatefulSharedComponentPreview: View {
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
        case let .knowledgeLink(payload):
            KnowledgeLinkComponent(
                content: payload,
                conceptNames: SharedComponentPreviewFixtures.conceptNames
            )
        case let .enrichmentTask(payload):
            EnrichmentTaskComponent(
                content: payload,
                conceptNames: SharedComponentPreviewFixtures.conceptNames
            )
        case let .personalKnowledgePromotion(payload):
            PersonalKnowledgePromotionComponent(
                content: payload,
                activity: activity,
                conceptNames: SharedComponentPreviewFixtures.conceptNames,
                onAction: { _ in }
            )
        case let .personalKnowledgeRelation(payload):
            PersonalKnowledgeRelationComponent(
                content: payload,
                activity: activity,
                conceptNames: SharedComponentPreviewFixtures.conceptNames,
                onAction: { _ in }
            )
        case let .knowledgeChangeSummary(payload):
            KnowledgeChangeSummaryComponent(
                content: payload,
                hasConfirmedChanges: true,
                hasPendingCandidates: true
            )
        default:
            EmptyView()
        }
    }
}

private struct SharedLearningComponentsPreview: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(SharedComponentPreviewFixtures.sections, id: \.id) {
                    section in
                    StatefulSharedComponentPreview(section: section)
                }
            }
            .frame(maxWidth: 760)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview("공통·분기 · Chapter 2") {
    SharedLearningComponentsPreview()
        .frame(width: 820, height: 1_000)
}

#Preview("공통·분기 · 큰 텍스트") {
    SharedLearningComponentsPreview()
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(width: 820, height: 1_000)
}
