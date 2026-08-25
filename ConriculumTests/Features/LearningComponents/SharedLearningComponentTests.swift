import AppKit
import ComposableArchitecture
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct SharedLearningComponentTests {
    private let expectedTags: [LearningSectionTag] = [
        .knowledgeLink,
        .personalExpressionComparison,
        .learningStateSelection,
        .enrichmentTask,
        .completionCheck,
        .personalKnowledgePromotion,
        .personalKnowledgeRelation,
        .knowledgeChangeSummary,
    ]

    @Test
    func completionAndPersonalKnowledgeActionsRemainIndependent() async {
        let activityID: LearningActivityID = "activity-page01-completion"
        let personalAction = PersonalKnowledgeComponentAction.promotionConfirmed(
            activityID: "activity-page01-promotion",
            expression: "값과 규칙을 나누는 나의 기준"
        )
        let store = TestStore(
            initialState: LearningComponentFeature.State()
        ) {
            LearningComponentFeature()
        }

        await store.send(.completionAssessmentChanged(
            activityID: activityID,
            assessment: .ready
        )) {
            $0.completionAssessments[activityID] = .ready
        }
        await store.receive(.delegate(.activityFieldsChanged(
            activityID: activityID,
            fields: [
                ActivityResponseField(
                    key: LearningActivityFieldKey.completionAssessment,
                    values: [CompletionSelfAssessment.ready.rawValue]
                )
            ]
        )))

        await store.send(.personalKnowledge(personalAction))
        await store.receive(.delegate(.personalKnowledge(personalAction)))

        #expect(store.state.completionAssessments[activityID] == .ready)
    }

    @Test
    func enrichmentAppearsOnlyForTheRequiredLearningState() throws {
        let fixtures = try loadFixtures()
        let section = try #require(
            fixtures.sections.first { $0.content.tag == .enrichmentTask }
        )
        guard case let .enrichmentTask(content) = section.content else {
            Issue.record("확장·심화 fixture가 enrichmentTask가 아니다.")
            return
        }

        #expect(
            EnrichmentTaskComponent(
                content: content,
                selectedStateID: content.requiredStateID,
                conceptNames: fixtures.conceptNames
            ).isVisible
        )
        #expect(
            EnrichmentTaskComponent(
                content: content,
                selectedStateID: nil,
                conceptNames: fixtures.conceptNames
            ).isVisible == false
        )
    }

    @Test
    func everySharedTagRendersFromChapterTwoAtStandardAndLargeText() throws {
        let fixtures = try loadFixtures()
        #expect(fixtures.sections.map(\.content.tag) == expectedTags)

        let sizes: [(name: String, value: DynamicTypeSize)] = [
            ("standard", .large),
            ("accessibility", .accessibility3),
        ]
        for section in fixtures.sections {
            for size in sizes {
                let image = try render(
                    section,
                    conceptNames: fixtures.conceptNames,
                    dynamicTypeSize: size.value
                )

                #expect(abs(image.size.width - 720) < 0.5)
                #expect(image.size.height > 120)
                #expect(image.size.height < 3_200)
                #expect(sampledColorCount(in: image) > 2)

                try writeCaptureIfRequested(
                    image,
                    name: "shared-\(section.content.tag.rawValue)-\(size.name)"
                )
            }
        }
    }

    private func loadFixtures() throws -> (
        sections: [LearningSection],
        conceptNames: KnowledgeConceptNames
    ) {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let allSections = chapter.allPages.flatMap(\.sections)
        let sections = try expectedTags.map { tag in
            try #require(allSections.first { $0.content.tag == tag })
        }
        return (sections, KnowledgeConceptNames(catalog: catalog))
    }

    private func render(
        _ section: LearningSection,
        conceptNames: KnowledgeConceptNames,
        dynamicTypeSize: DynamicTypeSize
    ) throws -> NSBitmapImageRep {
        let activity = LearningActivityInput(
            activityID: section.activityID ?? "shared-preview-activity",
            fields: []
        ) { _, _ in }
        let rootView = component(
            for: section.content,
            activity: activity,
            conceptNames: conceptNames
        )
        .environment(\.dynamicTypeSize, dynamicTypeSize)
        .padding(24)
        .frame(width: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .fixedSize(horizontal: false, vertical: true)
        let hostingView = NSHostingView(rootView: rootView)
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: 720,
            height: max(fittingSize.height, 1)
        )
        hostingView.layoutSubtreeIfNeeded()
        let image = try #require(
            hostingView.bitmapImageRepForCachingDisplay(
                in: hostingView.bounds
            )
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: image)
        return image
    }

    private func component(
        for content: LearningSectionContent,
        activity: LearningActivityInput,
        conceptNames: KnowledgeConceptNames
    ) -> AnyView {
        switch content {
        case let .knowledgeLink(payload):
            AnyView(KnowledgeLinkComponent(
                content: payload,
                conceptNames: conceptNames
            ))
        case let .personalExpressionComparison(payload):
            AnyView(PersonalExpressionComparisonComponent(
                content: payload,
                personalExpression: nil,
                conceptNames: conceptNames,
                onAction: { _ in }
            ))
        case let .learningStateSelection(payload):
            AnyView(LearningStateSelectionComponent(
                content: payload,
                selectedStateID: "deeper",
                onSelectionChanged: { _ in }
            ))
        case let .enrichmentTask(payload):
            AnyView(EnrichmentTaskComponent(
                content: payload,
                selectedStateID: payload.requiredStateID,
                conceptNames: conceptNames
            ))
        case let .completionCheck(payload):
            AnyView(CompletionCheckComponent(
                content: payload,
                activityID: activity.activityID,
                assessment: nil,
                onAssessmentChanged: { _, _ in }
            ))
        case let .personalKnowledgePromotion(payload):
            AnyView(PersonalKnowledgePromotionComponent(
                content: payload,
                activity: activity,
                conceptNames: conceptNames,
                onAction: { _ in }
            ))
        case let .personalKnowledgeRelation(payload):
            AnyView(PersonalKnowledgeRelationComponent(
                content: payload,
                activity: activity,
                conceptNames: conceptNames,
                onAction: { _ in }
            ))
        case let .knowledgeChangeSummary(payload):
            AnyView(KnowledgeChangeSummaryComponent(
                content: payload,
                hasConfirmedChanges: true,
                hasPendingCandidates: true
            ))
        default:
            AnyView(EmptyView())
        }
    }

    private func writeCaptureIfRequested(
        _ image: NSBitmapImageRep,
        name: String
    ) throws {
        guard let directory = ProcessInfo.processInfo.environment[
            "CONRICULUM_SHARED_CAPTURE_DIRECTORY"
        ] else { return }
        let data = try #require(
            image.representation(using: .png, properties: [:])
        )
        try data.write(
            to: URL(fileURLWithPath: directory)
                .appendingPathComponent("\(name).png")
        )
    }

    private func sampledColorCount(
        in image: NSBitmapImageRep
    ) -> Int {
        let horizontalStep = max(image.pixelsWide / 24, 1)
        let verticalStep = max(image.pixelsHigh / 24, 1)
        var colors: Set<Int> = []

        for x in stride(from: 0, to: image.pixelsWide, by: horizontalStep) {
            for y in stride(from: 0, to: image.pixelsHigh, by: verticalStep) {
                guard let color = image.colorAt(x: x, y: y)?
                    .usingColorSpace(.deviceRGB)
                else { continue }

                let red = Int(color.redComponent * 15)
                let green = Int(color.greenComponent * 15)
                let blue = Int(color.blueComponent * 15)
                colors.insert((red << 8) | (green << 4) | blue)
            }
        }

        return colors.count
    }
}
