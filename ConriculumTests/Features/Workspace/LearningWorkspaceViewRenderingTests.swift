import AppKit
import ComposableArchitecture
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
@Suite(.serialized)
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

    @Test
    func focusModeRendersAtTheE2EWindowSize() throws {
        let view = LearningWorkspaceView(
            store: Store(
                initialState: LearningWorkspaceFeature.State(
                    chapterID: Chapter02.id,
                    pageID: "chapter-02-page-07",
                    isFocusModeEnabled: true
                )
            ) {
                LearningWorkspaceFeature()
            }
        )
        .frame(width: 900, height: 632)

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 900, height: 632)
        hostingView.layoutSubtreeIfNeeded()
        let image = try #require(
            hostingView.bitmapImageRepForCachingDisplay(
                in: hostingView.bounds
            )
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: image)

        #expect(abs(image.size.width - 900) < 0.5)
        #expect(abs(image.size.height - 632) < 0.5)
        #expect(sampledColorCount(in: image) > 2)
    }

    @Test
    func narrowWindowRendersWithBothSupportingPanelsWithoutOverflow()
        throws
    {
        var state = try workspaceStateWithInspector()
        state.sidebarMode = .visible
        state.isInspectorPresented = true

        try assertNarrowLayoutFits(state: state)
    }

    @Test
    func narrowWindowRendersWithOnlyInspectorWithoutOverflow() throws {
        var state = try workspaceStateWithInspector()
        state.sidebarMode = .hidden
        state.isInspectorPresented = true

        try assertNarrowLayoutFits(state: state)
    }

    private func assertNarrowLayoutFits(
        state: LearningWorkspaceFeature.State
    ) throws {
        let width = 720.0
        let height = 720.0
        let view = LearningWorkspaceView(
            store: Store(initialState: state) {
                LearningWorkspaceFeature()
            }
        )
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hostingView.layoutSubtreeIfNeeded()

        let horizontalOverflow = hostingView
            .visibleDescendantHorizontalOverflow()
        // NavigationSplitView의 좌측 소재는 macOS에서 24pt를 의도적으로
        // 바깥까지 그린다. 실제 콘텐츠가 잘리던 114pt 이동은 허용하지 않는다.
        #expect(
            horizontalOverflow.leading <= 24.5,
            "왼쪽 콘텐츠가 \(horizontalOverflow.leading)pt 잘렸습니다."
        )
        #expect(
            horizontalOverflow.trailing <= 0.5,
            "오른쪽 콘텐츠가 \(horizontalOverflow.trailing)pt 잘렸습니다."
        )
        let image = try #require(
            hostingView.bitmapImageRepForCachingDisplay(
                in: hostingView.bounds
            )
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: image)
        #expect(abs(image.size.width - width) < 0.5)
        #expect(sampledColorCount(in: image) > 2)
    }

    private func workspaceStateWithInspector()
        throws -> LearningWorkspaceFeature.State
    {
        let chapter = try ContentResourceDecoder().decode(
            Chapter.self,
            from: .chapter02
        )
        let catalog = try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let pageID: LearningPageID = "chapter-02-page-07"
        let snapshot = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: []
        )
        let item = try #require(snapshot.directConcepts.first)
        var state = LearningWorkspaceFeature.State(
            chapterID: chapter.id,
            pageID: pageID
        )
        state.chapter.chapter = chapter
        state.chapter.knowledgeCatalog = catalog
        state.knowledgeContext.snapshot = snapshot
        state.knowledgeContext.inspector = ConceptInspectorFeature.State(
            sourcePageTitle: snapshot.pageTitle,
            item: item,
            availableConcepts: snapshot.availableConcepts,
            baseRelations: snapshot.baseRelations,
            personalRelations: snapshot.personalRelations,
            relationCreationContract: snapshot.relationCreationContract
        )
        return state
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

private extension NSView {
    func visibleDescendantHorizontalOverflow() -> (
        leading: CGFloat,
        trailing: CGFloat
    ) {
        descendants.reduce(into: (leading: 0, trailing: 0)) {
            overflow,
            descendant in
            guard !descendant.isHidden,
                  descendant.alphaValue > 0,
                  descendant.bounds.width > 0
            else { return }

            let boundsInRoot = descendant.convert(descendant.bounds, to: self)
            overflow.leading = max(
                overflow.leading,
                bounds.minX - boundsInRoot.minX
            )
            overflow.trailing = max(
                overflow.trailing,
                boundsInRoot.maxX - bounds.maxX
            )
        }
    }

    var descendants: [NSView] {
        subviews.flatMap { [$0] + $0.descendants }
    }
}
