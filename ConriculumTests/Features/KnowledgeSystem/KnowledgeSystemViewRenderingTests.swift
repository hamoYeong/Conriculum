import AppKit
import ComposableArchitecture
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct KnowledgeSystemViewRenderingTests {
    @Test
    func shelfNetworkAndComparisonLayoutsRender() throws {
        let snapshot = try makeSnapshot()
        let fixtures: [Fixture] = [
            Fixture(
                name: "shelf-wide",
                size: CGSize(width: 1_100, height: 760),
                mode: .shelves,
                selectedConceptIDs: []
            ),
            Fixture(
                name: "network-narrow",
                size: CGSize(width: 720, height: 720),
                mode: .network,
                selectedConceptIDs: []
            ),
            Fixture(
                name: "comparison-wide",
                size: CGSize(width: 1_100, height: 760),
                mode: .network,
                selectedConceptIDs: ["concept-type", "concept-value"]
            ),
        ]

        for fixture in fixtures {
            var state = KnowledgeSystemFeature.State(snapshot: snapshot)
            state.displayMode = fixture.mode
            state.selectedConceptIDs = fixture.selectedConceptIDs

            let view = KnowledgeSystemView(
                store: Store(initialState: state) {
                    KnowledgeSystemFeature()
                }
            )
            .frame(width: fixture.size.width, height: fixture.size.height)

            let image = try render(view, size: fixture.size)
            #expect(image.size == fixture.size)
            #expect(sampledColorCount(in: image) > 3)
            try writeCaptureIfRequested(image, name: fixture.name)
        }
    }

    private func makeSnapshot() throws -> KnowledgeSystemSnapshot {
        let catalog = try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let revision = PersonalConceptRevision(
            id: "render-revision-type",
            conceptID: "concept-type",
            personalTitle: "할 수 있는 일의 약속",
            explanation: "값의 가능한 사용을 함께 설명한다.",
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: "render-activity",
            createdAt: Date(timeIntervalSince1970: 20)
        )
        return KnowledgeSystemSnapshotComposer().compose(
            catalog: catalog,
            revisions: [revision],
            personalRelations: []
        )
    }

    private func render<V: View>(
        _ view: V,
        size: CGSize
    ) throws -> NSBitmapImageRep {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        let image = try #require(
            hostingView.bitmapImageRepForCachingDisplay(
                in: hostingView.bounds
            )
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: image)
        return image
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

    private func writeCaptureIfRequested(
        _ image: NSBitmapImageRep,
        name: String
    ) throws {
        guard let directory = ProcessInfo.processInfo.environment[
            "CONRICULUM_KNOWLEDGE_CAPTURE_DIRECTORY"
        ] else { return }

        let data = try #require(
            image.representation(using: .png, properties: [:])
        )
        try data.write(
            to: URL(fileURLWithPath: directory)
                .appendingPathComponent("knowledge-system-\(name).png")
        )
    }
}

private struct Fixture {
    let name: String
    let size: CGSize
    let mode: KnowledgeSystemFeature.DisplayMode
    let selectedConceptIDs: [KnowledgeConceptID]
}
