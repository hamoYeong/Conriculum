import AppKit
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct V1SharedLearningComponentTests {
    private let expectedTags: [V1LearningSectionTag] = [
        .knowledgeLink,
        .enrichmentTask,
        .personalKnowledgePromotion,
        .personalKnowledgeRelation,
        .knowledgeChangeSummary,
    ]

    @Test
    func enrichmentExplainsThatItIsOptionalWithoutASeparateStateSelection() throws {
        let fixtures = try loadFixtures()
        let section = try #require(
            fixtures.sections.first { $0.content.tag == .enrichmentTask }
        )
        guard case let .enrichmentTask(content) = section.content else {
            Issue.record("확장·심화 fixture가 enrichmentTask가 아니다.")
            return
        }

        #expect(content.title == "더 깊게 가기")
        #expect(content.guidance.contains("펼쳐"))
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
        sections: [V1LearningSection],
        conceptNames: V1KnowledgeConceptNames
    ) {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(V1Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let allSections = chapter.allPages.flatMap(\.sections)
        let sections = try expectedTags.map { tag in
            try #require(allSections.first { $0.content.tag == tag })
        }
        return (sections, V1KnowledgeConceptNames(catalog: catalog))
    }

    private func render(
        _ section: V1LearningSection,
        conceptNames: V1KnowledgeConceptNames,
        dynamicTypeSize: DynamicTypeSize
    ) throws -> NSBitmapImageRep {
        let activity = V1LearningActivityInput(
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
        for content: V1LearningSectionContent,
        activity: V1LearningActivityInput,
        conceptNames: V1KnowledgeConceptNames
    ) -> AnyView {
        switch content {
        case let .knowledgeLink(payload):
            AnyView(V1KnowledgeLinkComponent(
                content: payload,
                conceptNames: conceptNames
            ))
        case let .enrichmentTask(payload):
            AnyView(V1EnrichmentTaskComponent(
                content: payload,
                conceptNames: conceptNames
            ))
        case let .personalKnowledgePromotion(payload):
            AnyView(V1PersonalKnowledgePromotionComponent(
                content: payload,
                activity: activity,
                conceptNames: conceptNames,
                onAction: { _ in }
            ))
        case let .personalKnowledgeRelation(payload):
            AnyView(V1PersonalKnowledgeRelationComponent(
                content: payload,
                activity: activity,
                conceptNames: conceptNames,
                onAction: { _ in }
            ))
        case let .knowledgeChangeSummary(payload):
            AnyView(V1KnowledgeChangeSummaryComponent(
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
