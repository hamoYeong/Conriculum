import AppKit
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct V2StageComponentRenderingTests {
    @Test
    func gameAndLearningStagesRenderThroughDifferentComponents() throws {
        let store = V2BundledContentStore()
        let gamePage = try store.loadPage(id: .init(version: .v2, rawValue: "v2.s1.c1.p1"))
        let learningPage = try store.loadPage(id: .init(version: .v2, rawValue: "v2.s2.c1.p1"))

        let gameImage = try render(V2StageOneGameComponent(page: gamePage))
        let learningImage = try render(V2StageTwoLearningComponent(page: learningPage))

        #expect(gamePage.blocks.contains { $0.kind == .game })
        #expect(learningPage.blocks.contains { $0.kind == .codeStage })
        #expect(gameImage.pixelsHigh > 300)
        #expect(learningImage.pixelsHigh > 300)
    }

    private func render<Content: View>(_ view: Content) throws -> NSBitmapImageRep {
        let root = view
            .padding(24)
            .frame(width: 760)
            .background(Color(nsColor: .windowBackgroundColor))
            .fixedSize(horizontal: false, vertical: true)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 760, height: max(hosting.fittingSize.height, 1))
        hosting.layoutSubtreeIfNeeded()
        let image = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: image)
        return image
    }
}
