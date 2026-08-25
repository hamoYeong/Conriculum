import AppKit
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct KnowledgeContextViewRenderingTests {
    @Test
    func emptyAndPersonalizedSnapshotsRenderAtSidebarWidth() throws {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageID: LearningPageID = "chapter-02-page-05"
        let revision = PersonalConceptRevision(
            id: "revision-rendering",
            conceptID: "concept-constants-variables",
            personalTitle: "변경 책임 약속",
            explanation: "현재 책임 안에서 같은 이름에 새 값을 넣을지를 판단한다.",
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: "activity-page05-choice",
            createdAt: Date(timeIntervalSince1970: 1_725_782_400)
        )
        let snapshots = [
            try KnowledgeContextSnapshotComposer().compose(
                chapter: chapter,
                catalog: catalog,
                pageID: pageID,
                revisions: []
            ),
            try KnowledgeContextSnapshotComposer().compose(
                chapter: chapter,
                catalog: catalog,
                pageID: pageID,
                revisions: [revision]
            ),
        ]

        for snapshot in snapshots {
            let state = KnowledgeContextFeature.State(
                chapterID: chapter.id,
                currentPageID: pageID,
                snapshot: snapshot
            )
            let view = KnowledgeContextView(
                store: Store(initialState: state) {
                    KnowledgeContextFeature()
                }
            )
            .frame(width: 320, height: 720)
            let hostingView = NSHostingView(rootView: view)
            hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 720)
            hostingView.layoutSubtreeIfNeeded()
            let image = try #require(
                hostingView.bitmapImageRepForCachingDisplay(
                    in: hostingView.bounds
                )
            )
            hostingView.cacheDisplay(in: hostingView.bounds, to: image)

            #expect(image.size == NSSize(width: 320, height: 720))
            #expect(sampledColorCount(in: image) > 3)
        }
    }

    private func loadChapter() throws -> Chapter {
        try ContentResourceDecoder().decode(Chapter.self, from: .chapter02)
    }

    private func loadCatalog() throws -> KnowledgeCatalog {
        try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
    }

    private func sampledColorCount(in image: NSBitmapImageRep) -> Int {
        let horizontalStep = max(image.pixelsWide / 20, 1)
        let verticalStep = max(image.pixelsHigh / 20, 1)
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
