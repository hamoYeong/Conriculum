import AppKit
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct ReadingLearningComponentRenderingTests {
    private let expectedTags: [LearningSectionTag] = [
        .knowledgeRecall,
        .situation,
        .comparison,
        .definition,
        .decisionCriteria,
        .codeExplanation,
        .processGuide,
    ]

    @Test
    func blockRolesSeparateFlowFromCheckpointsTasksAndFeedback() {
        #expect(LearningBlockRole.flow.usesSurface == false)
        #expect(LearningBlockRole.checkpoint.usesSurface)
        #expect(LearningBlockRole.task.usesSurface)
        #expect(LearningBlockRole.feedback.usesSurface)
    }

    @Test
    func learningIntentsUseStableActionSymbols() {
        #expect(LearningIntent.recall.systemImage == "arrow.counterclockwise")
        #expect(LearningIntent.context.systemImage == "text.bubble")
        #expect(LearningIntent.observe.systemImage == "eye")
        #expect(LearningIntent.encode.systemImage == "book.closed")
        #expect(LearningIntent.decide.systemImage == "checklist")
        #expect(LearningIntent.apply.systemImage == "hammer")
        #expect(LearningIntent.reflect.systemImage == "brain.head.profile")
        #expect(
            LearningIntent.feedback.systemImage
                == "exclamationmark.triangle"
        )
    }

    @Test
    func swiftCodeHighlighterPreservesSourceAndClassifiesCoreSyntax() {
        let source = #"""
        @State var count: Int = 20_000 // 주문 수
        let name = "Swift"
        let type = {{valueType}}
        """#
        let tokens = SwiftCodeHighlighter.tokens(in: source)

        #expect(tokens.map(\.text).joined() == source)
        #expect(tokens.contains(SwiftCodeToken(text: "@State", kind: .attribute)))
        #expect(tokens.contains(SwiftCodeToken(text: "var", kind: .keyword)))
        #expect(tokens.contains(SwiftCodeToken(text: "Int", kind: .type)))
        #expect(tokens.contains(SwiftCodeToken(text: "20_000", kind: .number)))
        #expect(tokens.contains(SwiftCodeToken(text: "// 주문 수", kind: .comment)))
        #expect(tokens.contains(SwiftCodeToken(text: "\"Swift\"", kind: .string)))
        #expect(tokens.contains(SwiftCodeToken(
            text: "{{valueType}}",
            kind: .placeholder
        )))
    }

    @Test
    func everyReadingTagRendersFromChapterTwoAtStandardAndLargeText() throws {
        let chapter = try ContentResourceDecoder().decode(
            Chapter.self,
            from: .chapter02
        )
        let allSections = chapter.allPages.flatMap(\.sections)
        let sections = try expectedTags.map { tag in
            try #require(allSections.first { $0.content.tag == tag })
        }

        #expect(sections.map(\.content.tag) == expectedTags)

        let sizes: [(name: String, value: DynamicTypeSize)] = [
            ("standard", .large),
            ("accessibility", .accessibility3),
        ]
        for section in sections {
            for size in sizes {
                let image = try render(
                    section.content,
                    dynamicTypeSize: size.value
                )

                #expect(abs(image.size.width - 720) < 0.5)
                #expect(image.size.height > 120)
                #expect(image.size.height < 2_400)
                #expect(sampledColorCount(in: image) > 2)

                try writeCaptureIfRequested(
                    image,
                    name: "reading-\(section.content.tag.rawValue)-\(size.name)"
                )
            }
        }
    }

    private func render(
        _ content: LearningSectionContent,
        dynamicTypeSize: DynamicTypeSize
    ) throws -> NSBitmapImageRep {
        let rootView = component(for: content)
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
        for content: LearningSectionContent
    ) -> AnyView {
        switch content {
        case let .knowledgeRecall(payload):
            AnyView(KnowledgeRecallComponent(content: payload))
        case let .situation(payload):
            AnyView(SituationComponent(content: payload))
        case let .comparison(payload):
            AnyView(ComparisonComponent(content: payload))
        case let .definition(payload):
            AnyView(DefinitionComponent(content: payload))
        case let .decisionCriteria(payload):
            AnyView(DecisionCriteriaComponent(content: payload))
        case let .codeExplanation(payload):
            AnyView(CodeExplanationComponent(content: payload))
        case let .processGuide(payload):
            AnyView(ProcessGuideComponent(content: payload))
        default:
            AnyView(EmptyView())
        }
    }

    private func writeCaptureIfRequested(
        _ image: NSBitmapImageRep,
        name: String
    ) throws {
        guard let directory = ProcessInfo.processInfo.environment[
            "CONRICULUM_READING_CAPTURE_DIRECTORY"
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
