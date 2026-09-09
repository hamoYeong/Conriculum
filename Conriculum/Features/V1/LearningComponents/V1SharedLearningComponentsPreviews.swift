import SwiftUI

private enum SharedComponentPreviewFixtures {
    static let tags: [V1LearningSectionTag] = [
        .knowledgeLink,
        .enrichmentTask,
        .personalKnowledgePromotion,
        .personalKnowledgeRelation,
        .knowledgeChangeSummary,
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

    static var conceptNames: V1KnowledgeConceptNames {
        guard let catalog = try? ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        ) else { return V1KnowledgeConceptNames(titles: [:]) }
        return V1KnowledgeConceptNames(catalog: catalog)
    }
}

private struct StatefulSharedComponentPreview: View {
    let section: V1LearningSection
    @State private var fields: [V1ActivityResponseField] = []

    private var activity: V1LearningActivityInput {
        V1LearningActivityInput(
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
            V1KnowledgeLinkComponent(
                content: payload,
                conceptNames: SharedComponentPreviewFixtures.conceptNames
            )
        case let .enrichmentTask(payload):
            V1EnrichmentTaskComponent(
                content: payload,
                conceptNames: SharedComponentPreviewFixtures.conceptNames
            )
        case let .personalKnowledgePromotion(payload):
            V1PersonalKnowledgePromotionComponent(
                content: payload,
                activity: activity,
                conceptNames: SharedComponentPreviewFixtures.conceptNames,
                onAction: { _ in }
            )
        case let .personalKnowledgeRelation(payload):
            V1PersonalKnowledgeRelationComponent(
                content: payload,
                activity: activity,
                conceptNames: SharedComponentPreviewFixtures.conceptNames,
                onAction: { _ in }
            )
        case let .knowledgeChangeSummary(payload):
            V1KnowledgeChangeSummaryComponent(
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

#Preview("공통·분기 · V1Chapter 2") {
    SharedLearningComponentsPreview()
        .frame(width: 820, height: 1_000)
}

#Preview("공통·분기 · 큰 텍스트") {
    SharedLearningComponentsPreview()
        .environment(\.dynamicTypeSize, .accessibility3)
        .frame(width: 820, height: 1_000)
}
