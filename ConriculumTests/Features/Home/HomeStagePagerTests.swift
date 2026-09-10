import Testing

@testable import Conriculum

@MainActor
struct HomeStagePagerTests {
    @Test
    func chapterCardsDistinguishCompletedCurrentAndUpcoming() throws {
        let manifest = try BundledContentStore().loadManifest()
        let firstChapter = try #require(manifest.stage(id: "s1")?.chapters.first)
        let currentChapter = try #require(manifest.stage(id: "s1")?.chapters.dropFirst().first)
        let upcomingChapter = try #require(manifest.stage(id: "s2")?.chapters.first)
        let currentPage = try #require(currentChapter.pages.first)
        let progress = CourseProgress(
            lastVisitedPageID: currentPage.id,
            completedPageIDs: Set(firstChapter.pages.map(\.id))
        )
        let resolver = ChapterStatusResolver(
            manifest: manifest,
            progress: progress
        )

        #expect(resolver.status(for: firstChapter) == .completed)
        #expect(resolver.status(for: currentChapter) == .current)
        #expect(resolver.status(for: upcomingChapter) == .upcoming)
    }

    @Test
    func freshProgressMarksFirstChapterCurrent() throws {
        let manifest = try BundledContentStore().loadManifest()
        let firstChapter = try #require(manifest.stage(id: "s1")?.chapters.first)
        let resolver = ChapterStatusResolver(
            manifest: manifest,
            progress: .empty
        )

        #expect(resolver.status(for: firstChapter) == .current)
    }

    @Test
    func completingCurrentChapterAdvancesHighlightToNextChapter() throws {
        let manifest = try BundledContentStore().loadManifest()
        let chapters = try #require(manifest.stage(id: "s1")?.chapters)
        let completedChapter = try #require(chapters.first)
        let nextChapter = try #require(chapters.dropFirst().first)
        let progress = CourseProgress(
            lastVisitedPageID: try #require(completedChapter.pages.last).id,
            completedPageIDs: Set(completedChapter.pages.map(\.id))
        )
        let resolver = ChapterStatusResolver(
            manifest: manifest,
            progress: progress
        )

        #expect(resolver.status(for: completedChapter) == .completed)
        #expect(resolver.status(for: nextChapter) == .current)
    }
}
