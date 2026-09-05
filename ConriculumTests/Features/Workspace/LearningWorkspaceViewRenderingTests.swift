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
                    chapterID: "chapter-02",
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
                    chapterID: "chapter-02",
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

    @Test(arguments: [680.0, 720.0, 899.0, 900.0, 1_100.0])
    func windowPrioritizesLearningAndInspectorWithoutOverflow(width: Double)
        throws
    {
        var state = try workspaceStateWithInspector()
        state.sidebarMode = .visible
        state.isInspectorPresented = true

        try assertLayoutFits(state: state, width: width)
    }

    @Test
    func panelLayoutRespondsWithoutChangingTheSavedSidebarPreference() {
        #expect(
            LearningWorkspacePanelLayout.resolve(
                availableWidth: 720,
                inspectorIsVisible: true,
                sidebarIsHidden: false
            ) == .learningAndInspector
        )
        #expect(
            LearningWorkspacePanelLayout.resolve(
                availableWidth: 1_100,
                inspectorIsVisible: true,
                sidebarIsHidden: false
            ) == .navigationAndInspector
        )
        #expect(
            LearningWorkspacePanelLayout.resolve(
                availableWidth: 1_100,
                inspectorIsVisible: true,
                sidebarIsHidden: true
            ) == .learningAndInspector
        )
        #expect(
            LearningWorkspacePanelLayout.resolve(
                availableWidth: 720,
                inspectorIsVisible: false,
                sidebarIsHidden: false
            ) == .navigation
        )
    }

    @Test(arguments: [680.0, 720.0, 1_100.0])
    func windowRendersWithOnlyInspectorWithoutOverflow(width: Double) throws {
        var state = try workspaceStateWithInspector()
        state.sidebarMode = .hidden
        state.isInspectorPresented = true

        try assertLayoutFits(state: state, width: width)
    }

    private func assertLayoutFits(
        state: LearningWorkspaceFeature.State,
        width: Double
    ) throws {
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
        let splitView = try #require(hostingView.descendants.compactMap {
            $0 as? NSSplitView
        }.first)
        let expectsSidebar = state.sidebarMode != .hidden && width >= 900
        #expect(splitView.arrangedSubviews.count == (expectsSidebar ? 3 : 2))
        #expect(
            horizontalOverflow.leading <= 0.5,
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
        if state.sidebarMode == .visible {
            let png = try #require(image.representation(using: .png, properties: [:]))
            Attachment.record(Array(png), named: "workspace-\(Int(width)).png")
        }
    }

    @Test
    func resizingPreservesMainScrollViewAndSidebarPreference() async throws {
        var state = try workspaceStateWithInspector()
        state.sidebarMode = .visible
        state.isInspectorPresented = true
        let store = Store(initialState: state) { LearningWorkspaceFeature() }
        let hostingView = NSHostingView(rootView: LearningWorkspaceView(store: store))
        hostingView.frame = NSRect(x: 0, y: 0, width: 1_100, height: 720)
        let window = NSWindow(contentRect: hostingView.frame, styleMask: [], backing: .buffered, defer: false)
        window.contentView = hostingView
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        await Task.yield()
        hostingView.layoutSubtreeIfNeeded()
        let split = try #require(hostingView.descendants.compactMap { $0 as? NSSplitView }.first)
        #expect(split.arrangedSubviews.count == 3)
        let mainScrollView = try #require(split.arrangedSubviews[1].descendants.compactMap {
            $0 as? NSScrollView
        }.first)
        let event = try #require(CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: -300,
            wheel2: 0,
            wheel3: 0
        ))
        mainScrollView.scrollWheel(with: try #require(NSEvent(cgEvent: event)))
        // ScrollView는 휠 입력을 다음 렌더링 주기에 반영한다.
        for _ in 0..<30 where mainScrollView.contentView.bounds.minY == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        hostingView.layoutSubtreeIfNeeded()
        #expect(mainScrollView.contentView.bounds.minY > 0,
                "초기 스크롤: \(mainScrollView.contentView.bounds), 문서: \(String(describing: mainScrollView.documentView?.frame))")

        for width in [680.0, 720.0, 900.0, 1_100.0] {
            hostingView.frame.size.width = width
            hostingView.layoutSubtreeIfNeeded()
            await Task.yield()
            let mainIndex = width < 900 ? 0 : 1
            let currentScrollView = try #require(split.arrangedSubviews[mainIndex].descendants.compactMap {
                $0 as? NSScrollView
            }.first)
            #expect(currentScrollView === mainScrollView)
            #expect(currentScrollView.contentView.bounds.minY > 0)
            #expect(store.sidebarMode == .visible)
            #expect(store.isInspectorPresented)
        }
    }

    @Test(arguments: [false, true])
    func panelsUseMaximumWidthsWhenOpenedAndReopened(
        inspectorInitiallyVisible: Bool
    ) async throws {
        var state = try workspaceStateWithInspector()
        state.sidebarMode = .visible
        state.isInspectorPresented = inspectorInitiallyVisible
        let store = Store(initialState: state) { LearningWorkspaceFeature() }
        let host = NSHostingView(rootView: LearningWorkspaceView(store: store))
        host.frame = NSRect(x: 0, y: 0, width: 1_440, height: 900)
        let window = NSWindow(
            contentRect: host.frame, styleMask: [], backing: .buffered, defer: false
        )
        window.contentView = host

        func settleLayout() async throws {
            for _ in 0..<5 {
                host.layoutSubtreeIfNeeded()
                try await Task.sleep(for: .milliseconds(10))
            }
        }

        try await settleLayout()
        let split = try #require(host.descendants.compactMap { $0 as? NSSplitView }.first)
        let mainScroll = try #require(split.arrangedSubviews[1].descendants.compactMap {
            $0 as? NSScrollView
        }.first)

        var checkpoint = 0
        func expectWidths(sidebar: Bool, inspector: Bool) throws {
            checkpoint += 1
            #expect(split.arrangedSubviews.count == 1 + (sidebar ? 1 : 0) + (inspector ? 1 : 0))
            if sidebar {
                let width = try #require(split.arrangedSubviews.first).frame.width
                #expect(abs(width - 300) < 0.5, "단계 \(checkpoint): 사이드바 \(width)pt")
            }
            if inspector {
                let width = try #require(split.arrangedSubviews.last).frame.width
                #expect(abs(width - 360) < 0.5, "단계 \(checkpoint): 인스펙터 \(width)pt")
            }
            let currentScroll = try #require(split.arrangedSubviews[sidebar ? 1 : 0]
                .descendants.compactMap { $0 as? NSScrollView }.first)
            #expect(currentScroll === mainScroll)
        }

        try expectWidths(sidebar: true, inspector: inspectorInitiallyVisible)
        for _ in 0..<2 {
            store.send(.sidebarModeChanged(.hidden))
            try await settleLayout()
            try expectWidths(sidebar: false, inspector: store.isInspectorPresented)
            store.send(.sidebarModeChanged(.visible))
            try await settleLayout()
            try expectWidths(sidebar: true, inspector: store.isInspectorPresented)

            store.send(.inspectorVisibilityButtonTapped)
            try await settleLayout()
            try expectWidths(sidebar: true, inspector: store.isInspectorPresented)
        }

        store.send(.focusModeButtonTapped)
        try await settleLayout()
        try expectWidths(sidebar: false, inspector: false)
        store.send(.focusModeButtonTapped)
        try await settleLayout()
        try expectWidths(sidebar: true, inspector: inspectorInitiallyVisible)

        for width in [680.0, 720.0, 900.0, 720.0] {
            host.frame.size.width = width
            try await settleLayout()
            let mainIndex = inspectorInitiallyVisible && width < 900 ? 0 : 1
            #expect(split.arrangedSubviews[mainIndex].frame.width >= 379.5)
        }
        host.frame.size.width = 1_440
        try await settleLayout()
        try expectWidths(sidebar: true, inspector: inspectorInitiallyVisible)

        // 사용자가 직접 옮긴 구분선은 일반적인 레이아웃 갱신에서 되돌리지 않는다.
        split.setPosition(250, ofDividerAt: 0)
        try await settleLayout()
        #expect(abs(try #require(split.arrangedSubviews.first).frame.width - 250) < 0.5)
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
        // 실제 분할 컨테이너와 스크롤 뷰의 배치만 검사한다.
        // 화면 밖 KeyViewProxy와 스크롤 문서의 bounds는 그려지는 패널이 아니다.
        descendants.filter {
            $0 is NSSplitView || $0 is NSScrollView || $0.superview is NSSplitView
        }.reduce(into: (leading: 0, trailing: 0)) {
            overflow,
            descendant in
            guard !descendant.isHiddenOrHasHiddenAncestor,
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
