import AppKit
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct V1InteractiveLearningComponentTests {
    private let expectedTags: [V1LearningSectionTag] = [
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

    @Test
    func inputChangesCarryTheActivityIdentityAndPreserveOtherFields() {
        let activityID: LearningActivityID = "activity-page-01-choice"
        let original = V1ActivityResponseField(
            key: V1LearningActivityFieldKey.reason,
            values: ["처음 이유"]
        )
        var receivedActivityID: LearningActivityID?
        var receivedFields: [V1ActivityResponseField] = []
        let input = V1LearningActivityInput(
            activityID: activityID,
            fields: [original]
        ) { updatedActivityID, fields in
            receivedActivityID = updatedActivityID
            receivedFields = fields
        }

        input.updating(
            key: V1LearningActivityFieldKey.choice("discount-rule"),
            values: ["rule"]
        )

        #expect(receivedActivityID == activityID)
        #expect(receivedFields.first == original)
        #expect(
            receivedFields.last
                == V1ActivityResponseField(
                    key: "choice.discount-rule",
                    values: ["rule"]
                )
        )
    }

    @Test
    func relationSelectionsUpdateTogetherWithoutDroppingTheExistingDraft() {
        let statement = V1ActivityResponseField(
            key: V1LearningActivityFieldKey.relationStatement,
            values: ["값 묶기의 경계는 타입 책임으로 이어진다."]
        )
        var receivedFields: [V1ActivityResponseField] = []
        let input = V1LearningActivityInput(
            activityID: "activity-page07-relation",
            fields: [statement]
        ) { _, fields in
            receivedFields = fields
        }

        input.updating(valuesByKey: [
            V1LearningActivityFieldKey.relationSourceConceptID: [
                "concept-related-value-grouping"
            ],
            V1LearningActivityFieldKey.relationTargetConceptID: [
                "concept-type-modeling"
            ],
        ])

        #expect(receivedFields.first == statement)
        #expect(receivedFields.contains(V1ActivityResponseField(
            key: V1LearningActivityFieldKey.relationSourceConceptID,
            values: ["concept-related-value-grouping"]
        )))
        #expect(receivedFields.contains(V1ActivityResponseField(
            key: V1LearningActivityFieldKey.relationTargetConceptID,
            values: ["concept-type-modeling"]
        )))
    }

    @Test
    func closureAssessmentPreservesReflectionFieldsInTheSameActivity() {
        let explanation = V1ActivityResponseField(
            key: V1LearningActivityFieldKey.reflectionFinalExplanation,
            values: ["값의 역할과 흐름으로 설명한다."]
        )
        var receivedFields: [V1ActivityResponseField] = []
        let input = V1LearningActivityInput(
            activityID: "activity-page09-closure",
            fields: [explanation]
        ) { _, fields in
            receivedFields = fields
        }

        input.updating(
            key: V1LearningActivityFieldKey.completionAssessment,
            values: [V1CompletionSelfAssessment.ready.rawValue]
        )

        #expect(receivedFields.first == explanation)
        #expect(receivedFields.last == V1ActivityResponseField(
            key: V1LearningActivityFieldKey.completionAssessment,
            values: [V1CompletionSelfAssessment.ready.rawValue]
        ))
    }

    @Test
    func everyInteractiveTagRendersFromChapterTwoAtStandardAndLargeText() throws {
        let chapter = try ContentResourceDecoder().decode(
            V1Chapter.self,
            from: .chapter02
        )
        let allSections = chapter.allPages.flatMap(\.sections)
        let sections = try expectedTags.map { tag in
            try #require(allSections.first { $0.content.tag == tag })
        }

        #expect(sections.map(\.content.tag) == expectedTags)
        #expect(sections.allSatisfy { $0.activityID != nil })

        let sizes: [(name: String, value: DynamicTypeSize)] = [
            ("standard", .large),
            ("accessibility", .accessibility3),
        ]
        for section in sections {
            for size in sizes {
                let image = try render(
                    section,
                    dynamicTypeSize: size.value
                )

                #expect(abs(image.size.width - 720) < 0.5)
                #expect(image.size.height > 180)
                #expect(image.size.height < 2_800)
                #expect(sampledColorCount(in: image) > 2)

                try writeCaptureIfRequested(
                    image,
                    name: "interactive-\(section.content.tag.rawValue)-\(size.name)"
                )
            }
        }
    }

    private func render(
        _ section: V1LearningSection,
        dynamicTypeSize: DynamicTypeSize
    ) throws -> NSBitmapImageRep {
        let activity = V1LearningActivityInput(
            activityID: try #require(section.activityID),
            fields: []
        ) { _, _ in }
        let rootView = component(
            for: section.content,
            activity: activity
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
        for content: V1LearningSectionContent,
        activity: V1LearningActivityInput
    ) -> AnyView {
        switch content {
        case let .learningCompass(payload):
            AnyView(V1LearningCompassComponent(content: payload, activity: activity))
        case let .cardSorting(payload):
            AnyView(V1CardSortingComponent(content: payload, activity: activity))
        case let .matching(payload):
            AnyView(V1MatchingComponent(content: payload, activity: activity))
        case let .choiceWithReason(payload):
            AnyView(V1ChoiceWithReasonComponent(content: payload, activity: activity))
        case let .fillInBlank(payload):
            AnyView(V1FillInBlankComponent(content: payload, activity: activity))
        case let .codeAssembly(payload):
            AnyView(V1CodeAssemblyComponent(content: payload, activity: activity))
        case let .freeResponse(payload):
            AnyView(V1FreeResponseComponent(content: payload, activity: activity))
        case let .recallCheck(payload):
            AnyView(V1RecallCheckComponent(content: payload, activity: activity))
        case let .semanticChunkReading(payload):
            AnyView(V1SemanticChunkReadingComponent(content: payload, activity: activity))
        case let .learningClosure(payload):
            AnyView(V1LearningClosureComponent(content: payload, activity: activity))
        default:
            AnyView(EmptyView())
        }
    }

    private func writeCaptureIfRequested(
        _ image: NSBitmapImageRep,
        name: String
    ) throws {
        guard let directory = ProcessInfo.processInfo.environment[
            "CONRICULUM_INTERACTIVE_CAPTURE_DIRECTORY"
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
