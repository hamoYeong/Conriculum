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
        let relation = PersonalKnowledgeRelation(
            id: "relation-rendering",
            sourceConceptID: "concept-constants-variables",
            targetConceptID: "concept-problem-boundary",
            statement: "변경 가능성은 문제 경계의 책임과 연결된다.",
            reason: "어디에서 값이 바뀌어야 하는지 범위를 먼저 정하기 때문이다.",
            evidenceActivityID: "activity-page05-card-sorting",
            createdAt: revision.createdAt.addingTimeInterval(60)
        )
        let pendingReview = KnowledgePersonalizationReview(
            candidate: KnowledgePersonalizationCandidate(
                id: "candidate-rendering",
                kind: .conceptRevision,
                conceptIDs: [
                    "concept-constants-variables",
                    "concept-problem-boundary",
                ],
                draft: "값의 변경 여부는 현재 문제 경계의 책임으로 판단한다.",
                evidenceActivityID: "activity-page05-card-sorting",
                createdAt: relation.createdAt.addingTimeInterval(60)
            ),
            targetConceptID: "concept-constants-variables",
            activityID: "activity-page05-promotion",
            confirmationQuestion: "이 설명을 나의 지식으로 반영할까?",
            savedFields: ["나의 설명", "근거 활동 ID"]
        )
        let fixtures: [(
            name: String,
            snapshot: KnowledgeContextSnapshot,
            pendingReviews: [KnowledgePersonalizationReview]
        )] = [
            (
                "empty",
                try KnowledgeContextSnapshotComposer().compose(
                    chapter: chapter,
                    catalog: catalog,
                    pageID: pageID,
                    revisions: []
                ),
                []
            ),
            (
                "personalized",
                try KnowledgeContextSnapshotComposer().compose(
                    chapter: chapter,
                    catalog: catalog,
                    pageID: pageID,
                    revisions: [revision],
                    relations: [relation]
                ),
                [pendingReview]
            ),
        ]

        for fixture in fixtures {
            let state = KnowledgeContextFeature.State(
                chapterID: chapter.id,
                currentPageID: pageID,
                snapshot: fixture.snapshot,
                pendingPersonalizationReviews: fixture.pendingReviews
            )
            let view = KnowledgeContextView(
                store: Store(initialState: state) {
                    KnowledgeContextFeature()
                }
            )
            .frame(width: 320, height: 900)
            let hostingView = NSHostingView(rootView: view)
            hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 900)
            hostingView.layoutSubtreeIfNeeded()
            let image = try #require(
                hostingView.bitmapImageRepForCachingDisplay(
                    in: hostingView.bounds
                )
            )
            hostingView.cacheDisplay(in: hostingView.bounds, to: image)

            #expect(image.size == NSSize(width: 320, height: 900))
            #expect(sampledColorCount(in: image) > 3)

            try writeCaptureIfRequested(image, name: fixture.name)
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

    private func writeCaptureIfRequested(
        _ image: NSBitmapImageRep,
        name: String
    ) throws {
        guard let directory = ProcessInfo.processInfo.environment[
            "CONRICULUM_KNOWLEDGE_CONTEXT_CAPTURE_DIRECTORY"
        ] else { return }
        let data = try #require(
            image.representation(using: .png, properties: [:])
        )
        try data.write(
            to: URL(fileURLWithPath: directory)
                .appendingPathComponent("knowledge-context-\(name).png")
        )
    }
}
