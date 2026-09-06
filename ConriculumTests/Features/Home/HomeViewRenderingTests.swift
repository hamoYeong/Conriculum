import AppKit
import ComposableArchitecture
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct HomeViewRenderingTests {
    @Test
    func emptyAndPopulatedPreviewsRenderAtAStandardWindowSize() async throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(Chapter.self, from: .chapter02)
        let next = try decoder.decode(Chapter.self, from: .chapter(stageNumber: 1, chapterNumber: 3))
        let liveSnapshot = HomeSnapshotComposer().compose(chapter: chapter,
            catalog: try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes),
            progress: nil, responses: [], evidence: [], revisions: [], availableChapters: [chapter, next])
        let fixtures: [(name: String, snapshot: HomeSnapshot)] = [
            ("available-chapters", liveSnapshot),
            ("empty", HomePreviewFixtures.empty),
            ("populated", HomePreviewFixtures.mock),
        ]

        for fixture in fixtures {
            let view = HomeView(
                store: Store(
                    initialState: HomeFeature.State(
                        snapshot: fixture.snapshot,
                        usesSnapshotAsPlaceholder: true
                    )
                ) {
                    HomeFeature()
                }
            )
            .frame(width: 960, height: 900)

            try await assertRenders(view, name: fixture.name)
        }
    }

    @Test
    func v2HomeWithStagePagerAndKnowledgeBookshelfRenders() async throws {
        let manifest = try V2BundledContentStore().loadManifest()
        let firstChapter = try #require(manifest.stages.first?.chapters.first)
        var state = HomeFeature.State(
            snapshot: HomePreviewFixtures.mock,
            usesSnapshotAsPlaceholder: true
        )
        state.selectedContentVersion = .v2
        state.v2Manifest = manifest
        state.v2Progress = V2Progress(
            lastVisitedPageID: try #require(firstChapter.pages.first).id,
            completedPageIDs: []
        )

        let view = HomeView(
            store: Store(initialState: state) { HomeFeature() }
        )
        .frame(width: 960, height: 900)

        try await assertRenders(view, name: "v2-stage-pager-and-bookshelf")
    }

    private func assertRenders<Content: View>(
        _ view: Content,
        name: String
    ) async throws {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 960, height: 900)
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.appearance = NSAppearance(named: .aqua)
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(150))
        hostingView.layoutSubtreeIfNeeded()
        let image = try #require(
            hostingView.bitmapImageRepForCachingDisplay(
                in: hostingView.bounds
            )
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: image)

        #expect(image.size.width == 960)
        #expect(image.size.height == 900)
        #expect(sampledColorCount(in: image) > 2)

        try writeCaptureIfRequested(image, name: name)
    }

    private func writeCaptureIfRequested(
        _ image: NSBitmapImageRep,
        name: String
    ) throws {
        let data = try #require(
            image.representation(using: .png, properties: [:])
        )
        Attachment.record(Array(data), named: "home-\(name).png")
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
