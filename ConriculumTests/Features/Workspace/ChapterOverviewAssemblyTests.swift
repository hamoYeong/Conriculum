import AppKit
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct ChapterOverviewAssemblyTests {
    private let timestamp = Date(timeIntervalSince1970: 1_725_782_400)

    @Test
    func overviewContainsTheSixCriteriaAndEightPageRoute() throws {
        let chapter = try loadChapter()

        #expect(Chapter02ContentAssembly.isAssembled(chapter.overview))
        #expect(chapter.progressDenominator == 8)
        #expect(chapter.progressPages.compactMap(\.order) == Array(1...8))
        #expect(chapter.overview.sections.map(\.content.tag) == [
            .situation,
            .processGuide,
            .knowledgeLink,
        ])

        let processSection = try #require(
            chapter.overview.sections.first {
                $0.content.tag == .processGuide
            }
        )
        guard case let .processGuide(content) = processSection.content else {
            Issue.record("overview 완료 기준이 processGuide가 아니다.")
            return
        }
        #expect(content.steps.count == 6)
    }

    @Test
    func startSavesPageOneAsTheNextPosition() async throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let firstPageID = try #require(chapter.progressPageIDs.first)
        let expectedProgress = LearningProgress(
            chapterID: chapter.id,
            currentPageID: firstPageID,
            completedPageIDs: [],
            updatedAt: timestamp
        )
        var state = ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: chapter.overview.id
        )
        state.chapter = chapter
        state.knowledgeCatalog = catalog
        let store = TestStore(initialState: state) {
            ChapterLearningFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.learningRecordClient.saveProgress = { progress in
                #expect(progress == expectedProgress)
            }
        }

        await store.send(.startButtonTapped) {
            $0.isSavingNavigation = true
        }
        await store.receive(.navigationResponse(.saved(
            destination: .page(firstPageID),
            progress: expectedProgress,
            drafts: [],
            responses: []
        ))) {
            $0.isSavingNavigation = false
            $0.currentPageID = firstPageID
        }
        await store.receive(.delegate(.currentPageChanged(firstPageID)))
    }

    @Test
    func overviewRendersItsSectionsAndRouteMapAtBothTextSizes() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let sizes: [(name: String, value: DynamicTypeSize)] = [
            ("standard", .large),
            ("accessibility", .accessibility3),
        ]

        for size in sizes {
            var state = ChapterLearningFeature.State(
                chapterID: chapter.id,
                currentPageID: chapter.overview.id
            )
            state.chapter = chapter
            state.knowledgeCatalog = catalog
            let view = ChapterLearningView(
                store: Store(initialState: state) {
                    ChapterLearningFeature()
                }
            )
            .environment(\.dynamicTypeSize, size.value)
            .frame(width: 760, height: 900)
            let hostingView = NSHostingView(rootView: view)
            hostingView.frame = NSRect(x: 0, y: 0, width: 760, height: 900)
            hostingView.layoutSubtreeIfNeeded()
            let image = try #require(
                hostingView.bitmapImageRepForCachingDisplay(
                    in: hostingView.bounds
                )
            )
            hostingView.cacheDisplay(in: hostingView.bounds, to: image)

            #expect(abs(image.size.width - 760) < 0.5)
            #expect(abs(image.size.height - 900) < 0.5)
            #expect(sampledColorCount(in: image) > 3)
            try writeCaptureIfRequested(
                image,
                name: "chapter-overview-\(size.name)"
            )
        }
    }

    private func loadChapter() throws -> Chapter {
        try ContentResourceDecoder().decode(Chapter.self, from: .chapter02)
    }

    private func loadKnowledgeCatalog() throws -> KnowledgeCatalog {
        try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
    }

    private func writeCaptureIfRequested(
        _ image: NSBitmapImageRep,
        name: String
    ) throws {
        guard let directory = ProcessInfo.processInfo.environment[
            "CONRICULUM_OVERVIEW_CAPTURE_DIRECTORY"
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
