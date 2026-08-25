import AppKit
import ComposableArchitecture
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct LearningWorkspaceViewRenderingTests {
    @Test(arguments: [720.0, 1_100.0])
    func shellRendersAtNarrowAndWideWindowWidths(
        width: Double
    ) throws {
        let view = LearningWorkspaceView(
            store: Store(
                initialState: LearningWorkspaceFeature.State(
                    chapterID: Chapter02.id,
                    pageID: "chapter-02-overview"
                )
            ) {
                LearningWorkspaceFeature()
            }
        )
        .frame(width: width, height: 720)

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: 720)
        hostingView.layoutSubtreeIfNeeded()
        let image = try #require(
            hostingView.bitmapImageRepForCachingDisplay(
                in: hostingView.bounds
            )
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: image)

        #expect(abs(image.size.width - width) < 0.5)
        #expect(abs(image.size.height - 720) < 0.5)
        #expect(sampledColorCount(in: image) > 2)
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
