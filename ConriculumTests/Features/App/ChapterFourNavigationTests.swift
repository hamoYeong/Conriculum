import ComposableArchitecture
import Foundation
import Testing
@testable import Conriculum

@MainActor
struct ChapterFourNavigationTests {
    @Test(arguments: ["new", "resume", "removed-page"])
    func chapterThreeCompletionOpensChapterFourAndPreservesProgress(_ scenario: String) async throws {
        let assembly = try AppAssembly.inMemory()
        let chapter = try await assembly.curriculumClient.loadChapter("chapter-03")
        let next = try await assembly.curriculumClient.loadChapter("chapter-04")
        let lastPageID = try #require(chapter.progressPageIDs.last)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_004)
        let saved = scenario == "new" ? nil : LearningProgress(
            chapterID: next.id,
            currentPageID: scenario == "resume" ? "chapter-04-page-05" : "chapter-04-removed-page",
            completedPageIDs: ["chapter-04-page-01", "chapter-04-page-02"],
            updatedAt: timestamp.addingTimeInterval(-100)
        )
        if let saved { try await assembly.learningRecordClient.saveProgress(saved) }
        let expectedPageID: LearningPageID = scenario == "resume" ? "chapter-04-page-05" : next.overview.id
        var state = AppFeature.State()
        state.route = .learningWorkspace(chapterID: chapter.id)
        state.workspace = .init(chapterID: chapter.id, pageID: lastPageID)
        state.workspace?.chapter.chapter = chapter
        state.workspace?.chapter.completedPageIDs = Set(chapter.progressPageIDs)
        let progress = LearningProgress(chapterID: chapter.id, currentPageID: lastPageID,
            completedPageIDs: Set(chapter.progressPageIDs), updatedAt: timestamp)
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            $0.date.now = timestamp
            $0.curriculumClient = assembly.curriculumClient
            $0.learningRecordClient = assembly.learningRecordClient
        }
        await store.send(.workspace(.chapter(.nextButtonTapped))) {
            $0.workspace?.chapter.isSavingNavigation = true
        }
        await store.receive(.workspace(.chapter(.navigationResponse(.saved(
            destination: .completionSummary, progress: progress, drafts: [], responses: []
        ))))) {
            $0.workspace?.chapter.isSavingNavigation = false
            $0.workspace?.chapter.isShowingCompletionSummary = true
        }
        await store.send(.workspace(.chapter(.nextChapterButtonTapped))) {
            $0.workspace?.chapter.isSavingNavigation = true
        }
        await store.receive(.workspace(.chapter(.nextChapterResolved(next.id, expectedPageID)))) {
            $0.workspace?.chapter.isSavingNavigation = false
        }
        await store.receive(.workspace(.chapter(.delegate(.chapterRequested(next.id, expectedPageID)))))
        await store.receive(.workspace(.delegate(.chapterRequested(next.id, expectedPageID)))) {
            $0.route = .learningWorkspace(chapterID: next.id)
            $0.workspace = .init(chapterID: next.id, pageID: expectedPageID)
        }
        let savedNext = try await assembly.learningRecordClient.loadProgress(next.id)
        #expect(savedNext?.currentPageID == expectedPageID)
        #expect(savedNext?.completedPageIDs == saved?.completedPageIDs ?? [])
        let savedPrevious = try await assembly.learningRecordClient.loadProgress(chapter.id)
        #expect(savedPrevious == progress)
    }

    @Test
    func failedChapterFourProgressSaveKeepsCompletionAvailableAndCanRetry() async throws {
        let content = BundledContentStore()
        let chapter = try content.loadChapter("chapter-03")
        let next = try content.loadChapter("chapter-04")
        let failSave = LockIsolated(true)
        var state = ChapterLearningFeature.State(chapterID: chapter.id, currentPageID: try #require(chapter.progressPageIDs.last))
        state.chapter = chapter
        state.isShowingCompletionSummary = true
        let error = NSError(domain: "ChapterFourNavigation", code: 1, userInfo: [NSLocalizedDescriptionKey: "기록을 저장할 수 없습니다."])
        let store = TestStore(initialState: state) { ChapterLearningFeature() } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_800_000_004)
            $0.curriculumClient.loadChapters = { [chapter, next] }
            $0.learningRecordClient.loadProgress = { _ in nil }
            $0.learningRecordClient.saveProgress = { _ in
                if failSave.value { throw error }
            }
        }
        await store.send(.nextChapterButtonTapped) { $0.isSavingNavigation = true }
        await store.receive(.nextChapterFailed(error.localizedDescription)) {
            $0.isSavingNavigation = false
            $0.navigationErrorMessage = error.localizedDescription
        }
        #expect(store.state.isShowingCompletionSummary)
        failSave.setValue(false)
        await store.send(.nextChapterButtonTapped) {
            $0.isSavingNavigation = true
            $0.navigationErrorMessage = nil
        }
        await store.receive(.nextChapterResolved(next.id, next.overview.id)) {
            $0.isSavingNavigation = false
        }
        await store.receive(.delegate(.chapterRequested(next.id, next.overview.id)))
    }
}
