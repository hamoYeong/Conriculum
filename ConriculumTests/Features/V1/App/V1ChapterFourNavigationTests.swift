import ComposableArchitecture
import Foundation
import Testing
@testable import Conriculum

@MainActor
struct V1ChapterFourNavigationTests {
    @Test(arguments: ["new", "resume", "removed-page"])
    func chapterThreeCompletionOpensChapterFourAndPreservesProgress(_ scenario: String) async throws {
        let assembly = try AppAssembly.inMemory()
        let chapter = try await assembly.v1CurriculumClient.loadChapter("chapter-03")
        let next = try await assembly.v1CurriculumClient.loadChapter("chapter-04")
        let lastPageID = try #require(chapter.progressPageIDs.last)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_004)
        let saved = scenario == "new" ? nil : V1LearningProgress(
            chapterID: next.id,
            currentPageID: scenario == "resume" ? "chapter-04-page-05" : "chapter-04-removed-page",
            completedPageIDs: ["chapter-04-page-01", "chapter-04-page-02"],
            updatedAt: timestamp.addingTimeInterval(-100)
        )
        if let saved { try await assembly.v1LearningRecordClient.saveProgress(saved) }
        let expectedPageID: LearningPageID = scenario == "resume" ? "chapter-04-page-05" : next.overview.id
        var state = AppFeature.State()
        state.route = .v1Learning(chapterID: chapter.id)
        state.v1Workspace = .init(chapterID: chapter.id, pageID: lastPageID)
        state.v1Workspace?.chapter.chapter = chapter
        state.v1Workspace?.chapter.completedPageIDs = Set(chapter.progressPageIDs)
        let progress = V1LearningProgress(chapterID: chapter.id, currentPageID: lastPageID,
            completedPageIDs: Set(chapter.progressPageIDs), updatedAt: timestamp)
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            $0.date.now = timestamp
            $0.v1CurriculumClient = assembly.v1CurriculumClient
            $0.v1LearningRecordClient = assembly.v1LearningRecordClient
        }
        await store.send(.v1Workspace(.chapter(.nextButtonTapped))) {
            $0.v1Workspace?.chapter.isSavingNavigation = true
        }
        await store.receive(.v1Workspace(.chapter(.navigationResponse(.saved(
            destination: .completionSummary, progress: progress, drafts: [], responses: []
        ))))) {
            $0.v1Workspace?.chapter.isSavingNavigation = false
            $0.v1Workspace?.chapter.isShowingCompletionSummary = true
        }
        await store.send(.v1Workspace(.chapter(.nextChapterButtonTapped))) {
            $0.v1Workspace?.chapter.isSavingNavigation = true
        }
        await store.receive(.v1Workspace(.chapter(.nextChapterResolved(next.id, expectedPageID)))) {
            $0.v1Workspace?.chapter.isSavingNavigation = false
        }
        await store.receive(.v1Workspace(.chapter(.delegate(.v1ChapterRequested(next.id, expectedPageID)))))
        await store.receive(.v1Workspace(.delegate(.v1ChapterRequested(next.id, expectedPageID)))) {
            $0.route = .v1Learning(chapterID: next.id)
            $0.v1Workspace = .init(chapterID: next.id, pageID: expectedPageID)
        }
        let savedNext = try await assembly.v1LearningRecordClient.loadProgress(next.id)
        #expect(savedNext?.currentPageID == expectedPageID)
        #expect(savedNext?.completedPageIDs == saved?.completedPageIDs ?? [])
        let savedPrevious = try await assembly.v1LearningRecordClient.loadProgress(chapter.id)
        #expect(savedPrevious == progress)
    }

    @Test
    func failedChapterFourProgressSaveKeepsCompletionAvailableAndCanRetry() async throws {
        let content = V1BundledContentStore()
        let chapter = try content.loadChapter("chapter-03")
        let next = try content.loadChapter("chapter-04")
        let failSave = LockIsolated(true)
        var state = V1ChapterLearningFeature.State(chapterID: chapter.id, currentPageID: try #require(chapter.progressPageIDs.last))
        state.chapter = chapter
        state.isShowingCompletionSummary = true
        let error = NSError(domain: "ChapterFourNavigation", code: 1, userInfo: [NSLocalizedDescriptionKey: "기록을 저장할 수 없습니다."])
        let store = TestStore(initialState: state) { V1ChapterLearningFeature() } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_800_000_004)
            $0.v1CurriculumClient.loadChapters = { [chapter, next] }
            $0.v1LearningRecordClient.loadProgress = { _ in nil }
            $0.v1LearningRecordClient.saveProgress = { _ in
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
        await store.receive(.delegate(.v1ChapterRequested(next.id, next.overview.id)))
    }
}
