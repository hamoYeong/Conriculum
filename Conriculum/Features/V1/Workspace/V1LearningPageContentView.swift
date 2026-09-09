import ComposableArchitecture
import SwiftUI

struct V1LearningPageContentView: View {
    let chapter: V1Chapter
    let page: V1LearningPage
    let store: StoreOf<V1ChapterLearningFeature>

    private var conceptNames: V1KnowledgeConceptNames {
        guard let catalog = store.knowledgeCatalog else {
            return V1KnowledgeConceptNames(titles: [:])
        }
        return V1KnowledgeConceptNames(catalog: catalog)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(
                page.sections.sorted(by: Self.sectionOrder),
                id: \.id
            ) { section in
                if let title = section.title {
                    Text(title)
                        .font(.title2.weight(.semibold))
                        .accessibilityHeading(.h2)
                        .padding(.top, 4)
                }

                V1LearningSectionView(
                    section: section,
                    conceptNames: conceptNames,
                    activity: activityInput(for: section),
                    componentState: store.component,
                    onComponentAction: {
                        store.send(.component($0))
                    }
                )
            }

            if page.kind == .overview {
                V1ChapterRouteMap(chapter: chapter)
            }
        }
    }

    private func activityInput(
        for section: V1LearningSection
    ) -> V1LearningActivityInput? {
        guard let activityID = section.activityID else { return nil }

        return V1LearningActivityInput(
            activityID: activityID,
            fields: store.activityDrafts[activityID]?.fields ?? [],
            onFieldsChanged: { activityID, fields in
                store.send(.activityDraftChanged(
                    activityID: activityID,
                    fields: fields
                ))
            },
            saveState: store.activitySaveStates[activityID] ?? .idle,
            onRetry: { activityID in
                store.send(.activityRetryButtonTapped(activityID))
            }
        )
    }

    nonisolated private static func sectionOrder(
        lhs: V1LearningSection,
        rhs: V1LearningSection
    ) -> Bool {
        (lhs.order, lhs.id.rawValue) < (rhs.order, rhs.id.rawValue)
    }
}

struct V1LearningSectionView: View {
    let section: V1LearningSection
    let conceptNames: V1KnowledgeConceptNames
    let activity: V1LearningActivityInput?
    let componentState: V1LearningComponentFeature.State
    let onComponentAction: (V1LearningComponentFeature.Action) -> Void

    @ViewBuilder
    var body: some View {
        switch section.content {
        case let .learningCompass(content):
            if let activity {
                V1LearningCompassComponent(
                    content: content,
                    activity: activity
                )
            } else {
                missingActivity
            }
        case let .situation(content):
            V1SituationComponent(content: content)
        case let .comparison(content):
            V1ComparisonComponent(content: content)
        case let .definition(content):
            V1DefinitionComponent(content: content)
        case let .decisionCriteria(content):
            V1DecisionCriteriaComponent(content: content)
        case let .codeExplanation(content):
            V1CodeExplanationComponent(content: content)
        case let .processGuide(content):
            V1ProcessGuideComponent(content: content)

        case let .cardSorting(content):
            if let activity {
                V1CardSortingComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .matching(content):
            if let activity {
                V1MatchingComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .choiceWithReason(content):
            if let activity {
                V1ChoiceWithReasonComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .fillInBlank(content):
            if let activity {
                V1FillInBlankComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .codeAssembly(content):
            if let activity {
                V1CodeAssemblyComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .freeResponse(content):
            if let activity {
                V1FreeResponseComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .recallCheck(content):
            if let activity {
                V1RecallCheckComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .learningClosure(content):
            if let activity {
                V1LearningClosureComponent(
                    content: content,
                    activity: activity
                )
            } else {
                missingActivity
            }
        case let .semanticChunkReading(content):
            if let activity {
                V1SemanticChunkReadingComponent(
                    content: content,
                    activity: activity
                )
            } else {
                missingActivity
            }

        case let .knowledgeLink(content):
            V1KnowledgeLinkComponent(
                content: content,
                conceptNames: conceptNames
            )
        case let .enrichmentTask(content):
            V1EnrichmentTaskComponent(
                content: content,
                conceptNames: conceptNames
            )
        case let .personalKnowledgePromotion(content):
            if let activity {
                V1PersonalKnowledgePromotionComponent(
                    content: content,
                    activity: activity,
                    conceptNames: conceptNames,
                    onAction: {
                        onComponentAction(.personalKnowledge($0))
                    }
                )
            } else {
                missingActivity
            }
        case let .personalKnowledgeRelation(content):
            if let activity {
                V1PersonalKnowledgeRelationComponent(
                    content: content,
                    activity: activity,
                    conceptNames: conceptNames,
                    onAction: {
                        onComponentAction(.personalKnowledge($0))
                    }
                )
            } else {
                missingActivity
            }
        case let .knowledgeChangeSummary(content):
            V1KnowledgeChangeSummaryComponent(
                content: content,
                hasConfirmedChanges: false,
                hasPendingCandidates: false
            )
        }
    }

    private var missingActivity: some View {
        LearningBlock(
            title: "활동 연결 오류",
            intent: .feedback,
            role: .feedback
        ) {
            Text("이 학습 블록에 활동 연결 정보가 없습니다.")
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel(
            "활동 연결 오류. 이 학습 블록에 활동 연결 정보가 없습니다."
        )
    }
}

struct V1ChapterRouteMap: View {
    let chapter: V1Chapter

    var body: some View {
        LearningBlock(
            title: "\(chapter.progressDenominator)개 페이지 학습 경로",
            intent: .context,
            role: .checkpoint
        ) {
            Text("각 페이지는 앞선 판단을 다음 판단의 근거로 이어 갑니다.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(chapter.progressPages, id: \.id) { page in
                    routeRow(page)
                }
            }
        }
    }

    private func routeRow(_ page: V1LearningPage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(page.order ?? 0)")
                .font(.callout.monospacedDigit().weight(.bold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(Color.blue.opacity(0.10), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(page.title)
                    .font(.headline)
                Text(page.goal)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(page.order ?? 0)번째 페이지. \(page.title). 목표. \(page.goal)"
        )
    }
}
