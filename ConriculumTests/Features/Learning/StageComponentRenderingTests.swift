import AppKit
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct StageComponentRenderingTests {
    @Test
    func gameAndLearningStagesRenderThroughDifferentComponents() throws {
        let store = BundledContentStore()
        let gamePage = try store.loadPage(id: "s1.c1.p1")
        let learningPage = try store.loadPage(id: "s2.c1.p1")

        let gameImage = try render(StageOneGameComponent(page: gamePage))
        let learningImage = try render(StageTwoLearningComponent(page: learningPage))

        #expect(gamePage.blocks.contains { $0.kind == .game })
        #expect(learningPage.blocks.contains { $0.kind == .codeStage })
        #expect(gameImage.pixelsHigh > 300)
        #expect(learningImage.pixelsHigh > 300)
    }

    @Test
    func wordSystemAndKnowledgeUnlockRenderAsDedicatedComponents() throws {
        let page = try BundledContentStore().loadPage(id: "s1.c1.p1")
        let wordSystem = try #require(page.blocks.compactMap(\.wordSystem).first)
        let knowledgeUnlock = try #require(page.blocks.compactMap(\.knowledgeUnlock).first)

        let wordImage = try render(WordSystemComponent(content: wordSystem))
        let unlockImage = try render(KnowledgeUnlockComponent(content: knowledgeUnlock))

        #expect(wordSystem.entries.count == 3)
        #expect(knowledgeUnlock.cards.count == 2)
        #expect(wordImage.pixelsHigh > 150)
        #expect(unlockImage.pixelsHigh > 180)
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
