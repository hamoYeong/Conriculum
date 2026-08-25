import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct ChapterLearningFeatureTests {
    private let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
    private let responseUUID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000001"
    )!

    @Test
    func validSavedPageIsResumedByIdentity() async throws {
        let chapter = try loadChapter()
        let savedPageID = try #require(chapter.progressPageIDs.dropFirst().first)
        let progress = LearningProgress(
            chapterID: chapter.id,
            currentPageID: savedPageID,
            completedPageIDs: [chapter.progressPageIDs[0]],
            updatedAt: timestamp
        )
        let store = TestStore(
            initialState: ChapterLearningFeature.State(
                chapterID: chapter.id,
                currentPageID: chapter.overview.id
            )
        ) {
            ChapterLearningFeature()
        } withDependencies: {
            $0.curriculumClient.loadChapter = { _ in chapter }
            $0.learningRecordClient.loadProgress = { _ in progress }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(.loadResponse(.loaded(
            chapter: chapter,
            progress: progress
        ))) {
            $0.isLoading = false
            $0.chapter = chapter
            $0.currentPageID = savedPageID
            $0.completedPageIDs = [chapter.progressPageIDs[0]]
        }
        await store.receive(.delegate(.currentPageChanged(savedPageID)))
    }

    @Test
    func invalidSavedPageFallsBackToTheOverview() async throws {
        let chapter = try loadChapter()
        let invalidPageID: LearningPageID = "chapter-02-removed-page"
        let progress = LearningProgress(
            chapterID: chapter.id,
            currentPageID: invalidPageID,
            completedPageIDs: [invalidPageID],
            updatedAt: timestamp
        )
        let store = TestStore(
            initialState: ChapterLearningFeature.State(
                chapterID: chapter.id,
                currentPageID: invalidPageID
            )
        ) {
            ChapterLearningFeature()
        } withDependencies: {
            $0.curriculumClient.loadChapter = { _ in chapter }
            $0.learningRecordClient.loadProgress = { _ in progress }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(.loadResponse(.loaded(
            chapter: chapter,
            progress: progress
        ))) {
            $0.isLoading = false
            $0.chapter = chapter
            $0.currentPageID = chapter.overview.id
        }
        await store.receive(
            .delegate(.currentPageChanged(chapter.overview.id))
        )
    }

    @Test
    func firstPageDoesNotNavigateBackward() async throws {
        let chapter = try loadChapter()
        let firstPageID = try #require(chapter.progressPageIDs.first)
        var state = ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: firstPageID
        )
        state.chapter = chapter
        let store = TestStore(initialState: state) {
            ChapterLearningFeature()
        }

        #expect(store.state.canNavigatePrevious == false)
        await store.send(.previousButtonTapped)
    }

    @Test
    func lastPageSavesItsPositionBeforeShowingCompletionSummary() async throws {
        let chapter = try loadChapter()
        let lastPageID = try #require(chapter.progressPageIDs.last)
        let recorder = LearningRecordSaveRecorder()
        var state = ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: lastPageID
        )
        state.chapter = chapter
        let expectedProgress = LearningProgress(
            chapterID: chapter.id,
            currentPageID: lastPageID,
            completedPageIDs: [],
            updatedAt: timestamp
        )
        let store = TestStore(initialState: state) {
            ChapterLearningFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.learningRecordClient.saveProgress = { progress in
                await recorder.record(.progress(progress))
            }
        }

        await store.send(.nextButtonTapped) {
            $0.isSavingNavigation = true
        }
        await store.receive(.navigationResponse(.saved(
            destination: .completionSummary,
            progress: expectedProgress,
            draft: nil
        ))) {
            $0.isSavingNavigation = false
            $0.isShowingCompletionSummary = true
        }

        let events = await recorder.events()
        #expect(events.count == 1)
        guard case let .progress(savedProgress) = events.first else {
            Issue.record("마지막 페이지 위치가 저장되지 않았다.")
            return
        }
        #expect(savedProgress == expectedProgress)
    }

    @Test
    func draftAndTargetPageAreSavedBeforeStateMoves() async throws {
        let chapter = try loadChapter()
        let pageIDs = chapter.progressPageIDs
        let sourcePageID = try #require(pageIDs.first)
        let targetPageID = try #require(pageIDs.dropFirst().first)
        let activityID = try #require(
            chapter.page(id: sourcePageID)?.activities.first?.id
        )
        let fields = [
            ActivityResponseField(
                key: "reason",
                values: ["이번 사례에서 하나로 정해진 정보이기 때문이다."]
            )
        ]
        let recorder = LearningRecordSaveRecorder()
        var state = ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: sourcePageID
        )
        state.chapter = chapter
        let draft = ChapterLearningFeature.ActivityDraft(
            responseID: ActivityResponseID(
                rawValue: responseUUID.uuidString.lowercased()
            ),
            activityID: activityID,
            fields: fields
        )
        let expectedResponse = ActivityResponse(
            id: draft.responseID,
            activityID: activityID,
            pageID: sourcePageID,
            fields: fields,
            recordedAt: timestamp
        )
        let expectedProgress = LearningProgress(
            chapterID: chapter.id,
            currentPageID: targetPageID,
            completedPageIDs: [],
            updatedAt: timestamp
        )
        let store = TestStore(initialState: state) {
            ChapterLearningFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.uuid = .constant(responseUUID)
            $0.learningRecordClient.saveResponse = { response in
                await recorder.record(.response(response))
            }
            $0.learningRecordClient.saveProgress = { progress in
                await recorder.record(.progress(progress))
            }
        }

        await store.send(.activityDraftChanged(
            activityID: activityID,
            fields: fields
        )) {
            $0.currentDraft = draft
        }
        await store.send(.nextButtonTapped) {
            $0.isSavingNavigation = true
        }
        #expect(store.state.currentPageID == sourcePageID)

        await store.receive(.navigationResponse(.saved(
            destination: .page(targetPageID),
            progress: expectedProgress,
            draft: draft
        ))) {
            $0.isSavingNavigation = false
            $0.currentPageID = targetPageID
            $0.currentDraft = nil
        }
        await store.receive(.delegate(.currentPageChanged(targetPageID)))

        let events = await recorder.events()
        #expect(events.count == 2)
        guard case let .response(savedResponse) = events.first else {
            Issue.record("페이지 이동 전에 활동 응답이 저장되지 않았다.")
            return
        }
        guard case let .progress(savedProgress) = events.last else {
            Issue.record("활동 응답 뒤에 목표 페이지 위치가 저장되지 않았다.")
            return
        }
        #expect(savedResponse == expectedResponse)
        #expect(savedProgress == expectedProgress)
    }

    private func loadChapter() throws -> Chapter {
        try ContentResourceDecoder().decode(Chapter.self, from: .chapter02)
    }
}

private actor LearningRecordSaveRecorder {
    enum Event: Sendable {
        case response(ActivityResponse)
        case progress(LearningProgress)
    }

    private var recordedEvents: [Event] = []

    func record(_ event: Event) {
        recordedEvents.append(event)
    }

    func events() -> [Event] {
        recordedEvents
    }
}
