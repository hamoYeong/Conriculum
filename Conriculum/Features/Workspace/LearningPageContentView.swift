import ComposableArchitecture
import SwiftUI

struct LearningPageContentView: View {
    let chapter: Chapter
    let page: LearningPage
    let store: StoreOf<ChapterLearningFeature>

    private var conceptNames: KnowledgeConceptNames {
        guard let catalog = store.knowledgeCatalog else {
            return KnowledgeConceptNames(titles: [:])
        }
        return KnowledgeConceptNames(catalog: catalog)
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

                LearningSectionView(
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
                ChapterRouteMap(chapter: chapter)
            }
        }
    }

    private func activityInput(
        for section: LearningSection
    ) -> LearningActivityInput? {
        guard let activityID = section.activityID else { return nil }

        return LearningActivityInput(
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
        lhs: LearningSection,
        rhs: LearningSection
    ) -> Bool {
        (lhs.order, lhs.id.rawValue) < (rhs.order, rhs.id.rawValue)
    }
}

struct LearningSectionView: View {
    let section: LearningSection
    let conceptNames: KnowledgeConceptNames
    let activity: LearningActivityInput?
    let componentState: LearningComponentFeature.State
    let onComponentAction: (LearningComponentFeature.Action) -> Void

    @ViewBuilder
    var body: some View {
        switch section.content {
        case let .knowledgeRecall(content):
            KnowledgeRecallComponent(content: content)
        case let .situation(content):
            SituationComponent(content: content)
        case let .comparison(content):
            ComparisonComponent(content: content)
        case let .definition(content):
            DefinitionComponent(content: content)
        case let .decisionCriteria(content):
            DecisionCriteriaComponent(content: content)
        case let .codeExplanation(content):
            CodeExplanationComponent(content: content)
        case let .processGuide(content):
            ProcessGuideComponent(content: content)

        case let .cardSorting(content):
            if let activity {
                CardSortingComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .matching(content):
            if let activity {
                MatchingComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .choiceWithReason(content):
            if let activity {
                ChoiceWithReasonComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .fillInBlank(content):
            if let activity {
                FillInBlankComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .codeAssembly(content):
            if let activity {
                CodeAssemblyComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .freeResponse(content):
            if let activity {
                FreeResponseComponent(content: content, activity: activity)
            } else {
                missingActivity
            }
        case let .recallCheck(content):
            if let activity {
                RecallCheckComponent(content: content, activity: activity)
            } else {
                missingActivity
            }

        case let .knowledgeLink(content):
            KnowledgeLinkComponent(
                content: content,
                conceptNames: conceptNames
            )
        case let .personalExpressionComparison(content):
            PersonalExpressionComparisonComponent(
                content: content,
                personalExpression: nil,
                conceptNames: conceptNames,
                onAction: {
                    onComponentAction(.personalKnowledge($0))
                }
            )
        case let .learningStateSelection(content):
            LearningStateSelectionComponent(
                content: content,
                selectedStateID: componentState.selectedLearningStateID,
                onSelectionChanged: {
                    onComponentAction(.learningStateSelected($0))
                }
            )
        case let .enrichmentTask(content):
            EnrichmentTaskComponent(
                content: content,
                selectedStateID: componentState.selectedLearningStateID,
                conceptNames: conceptNames
            )
        case let .completionCheck(content):
            if let activity {
                VStack(alignment: .leading, spacing: 10) {
                    CompletionCheckComponent(
                        content: content,
                        activityID: activity.activityID,
                        assessment: componentState.completionAssessments[
                            activity.activityID
                        ],
                        onAssessmentChanged: { activityID, assessment in
                            onComponentAction(.completionAssessmentChanged(
                                activityID: activityID,
                                assessment: assessment
                            ))
                        }
                    )
                    ActivityDraftStatusView(activity: activity)
                }
            } else {
                missingActivity
            }
        case let .personalKnowledgePromotion(content):
            if let activity {
                PersonalKnowledgePromotionComponent(
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
                PersonalKnowledgeRelationComponent(
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
            KnowledgeChangeSummaryComponent(
                content: content,
                hasConfirmedChanges: false,
                hasPendingCandidates: false
            )
        }
    }

    private var missingActivity: some View {
        LearningBlock(
            title: "활동 연결 오류",
            systemImage: "exclamationmark.triangle",
            accent: .red,
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

struct ChapterRouteMap: View {
    let chapter: Chapter

    var body: some View {
        LearningBlock(
            title: "8개 페이지 학습 경로",
            systemImage: "map",
            accent: .blue
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

    private func routeRow(_ page: LearningPage) -> some View {
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
