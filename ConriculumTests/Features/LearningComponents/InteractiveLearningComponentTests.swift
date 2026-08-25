import AppKit
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct InteractiveLearningComponentTests {
    private let expectedTags: [LearningSectionTag] = [
        .cardSorting,
        .matching,
        .choiceWithReason,
        .fillInBlank,
        .codeAssembly,
        .freeResponse,
        .recallCheck,
    ]

    @Test
    func inputChangesCarryTheActivityIdentityAndPreserveOtherFields() {
        let activityID: LearningActivityID = "activity-page-01-choice"
        let original = ActivityResponseField(
            key: LearningActivityFieldKey.reason,
            values: ["처음 이유"]
        )
        var receivedActivityID: LearningActivityID?
        var receivedFields: [ActivityResponseField] = []
        let input = LearningActivityInput(
            activityID: activityID,
            fields: [original]
        ) { updatedActivityID, fields in
            receivedActivityID = updatedActivityID
            receivedFields = fields
        }

        input.updating(
            key: LearningActivityFieldKey.choice("discount-rule"),
            values: ["rule"]
        )

        #expect(receivedActivityID == activityID)
        #expect(receivedFields.first == original)
        #expect(
            receivedFields.last
                == ActivityResponseField(
                    key: "choice.discount-rule",
                    values: ["rule"]
                )
        )
    }

    @Test
    func everyInteractiveTagRendersFromChapterTwoAtStandardAndLargeText() throws {
        let chapter = try ContentResourceDecoder().decode(
            Chapter.self,
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
        _ section: LearningSection,
        dynamicTypeSize: DynamicTypeSize
    ) throws -> NSBitmapImageRep {
        let activity = LearningActivityInput(
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
        for content: LearningSectionContent,
        activity: LearningActivityInput
    ) -> AnyView {
        switch content {
        case let .cardSorting(payload):
            AnyView(CardSortingComponent(content: payload, activity: activity))
        case let .matching(payload):
            AnyView(MatchingComponent(content: payload, activity: activity))
        case let .choiceWithReason(payload):
            AnyView(ChoiceWithReasonComponent(content: payload, activity: activity))
        case let .fillInBlank(payload):
            AnyView(FillInBlankComponent(content: payload, activity: activity))
        case let .codeAssembly(payload):
            AnyView(CodeAssemblyComponent(content: payload, activity: activity))
        case let .freeResponse(payload):
            AnyView(FreeResponseComponent(content: payload, activity: activity))
        case let .recallCheck(payload):
            AnyView(RecallCheckComponent(content: payload, activity: activity))
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
