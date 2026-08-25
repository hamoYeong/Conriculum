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
        let knowledgeCatalog = try loadKnowledgeCatalog()
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
            $0.knowledgeCatalogClient.loadCatalog = { knowledgeCatalog }
            $0.learningRecordClient.loadProgress = { _ in progress }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(.loadResponse(.loaded(
            chapter: chapter,
            knowledgeCatalog: knowledgeCatalog,
            progress: progress
        ))) {
            $0.isLoading = false
            $0.chapter = chapter
            $0.knowledgeCatalog = knowledgeCatalog
            $0.currentPageID = savedPageID
            $0.completedPageIDs = [chapter.progressPageIDs[0]]
        }
        await store.receive(.delegate(.currentPageChanged(savedPageID)))
    }

    @Test
    func invalidSavedPageFallsBackToTheOverview() async throws {
        let chapter = try loadChapter()
        let knowledgeCatalog = try loadKnowledgeCatalog()
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
            $0.knowledgeCatalogClient.loadCatalog = { knowledgeCatalog }
            $0.learningRecordClient.loadProgress = { _ in progress }
        }

        await store.send(.task) {
            $0.isLoading = true
        }
        await store.receive(.loadResponse(.loaded(
            chapter: chapter,
            knowledgeCatalog: knowledgeCatalog,
            progress: progress
        ))) {
            $0.isLoading = false
            $0.chapter = chapter
            $0.knowledgeCatalog = knowledgeCatalog
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
            drafts: []
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
        let clock = TestClock()
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
            $0.continuousClock = clock
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
            $0.activityDrafts[activityID] = draft
            $0.activitySaveStates[activityID] = .pending
        }
        await store.send(.nextButtonTapped) {
            $0.isSavingNavigation = true
            $0.activitySaveStates[activityID] = .saving
        }
        #expect(store.state.currentPageID == sourcePageID)

        await store.receive(.navigationResponse(.saved(
            destination: .page(targetPageID),
            progress: expectedProgress,
            drafts: [draft]
        ))) {
            $0.isSavingNavigation = false
            $0.currentPageID = targetPageID
            $0.activityDrafts = [:]
            $0.activitySaveStates = [:]
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

    @Test
    func activityDraftAutosavesAfterTheDebounce() async throws {
        let chapter = try loadChapter()
        let pageID = try #require(chapter.progressPageIDs.first)
        let activityID = try #require(
            chapter.page(id: pageID)?.activities.first?.id
        )
        let fields = [
            ActivityResponseField(
                key: "reason",
                values: ["자동 저장할 설명"]
            )
        ]
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
            pageID: pageID,
            fields: fields,
            recordedAt: timestamp
        )
        let clock = TestClock()
        let recorder = LearningRecordSaveRecorder()
        var state = ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: pageID
        )
        state.chapter = chapter
        let store = TestStore(initialState: state) {
            ChapterLearningFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.date.now = timestamp
            $0.uuid = .constant(responseUUID)
            $0.learningRecordClient.saveResponse = { response in
                await recorder.record(.response(response))
            }
        }

        await store.send(.activityDraftChanged(
            activityID: activityID,
            fields: fields
        )) {
            $0.activityDrafts[activityID] = draft
            $0.activitySaveStates[activityID] = .pending
        }
        await clock.advance(by: .milliseconds(749))
        #expect(store.state.activitySaveStates[activityID] == .pending)
        await clock.advance(by: .milliseconds(1))
        await store.receive(.activityAutosaveDelayElapsed(activityID)) {
            $0.activitySaveStates[activityID] = .saving
        }
        await store.receive(.activitySaveResponse(
            activityID: activityID,
            response: .saved(draft: draft, savedAt: timestamp)
        )) {
            $0.activitySaveStates[activityID] = .saved(timestamp)
        }

        let events = await recorder.events()
        #expect(events.count == 1)
        guard case let .response(response) = events.first else {
            Issue.record("debounce 뒤 활동 응답이 저장되지 않았다.")
            return
        }
        #expect(response == expectedResponse)
    }

    @Test
    func persistenceFailureKeepsTheDraftAndRetriesTheSameResponse() async throws {
        let chapter = try loadChapter()
        let pageID = try #require(chapter.progressPageIDs.first)
        let activityID = try #require(
            chapter.page(id: pageID)?.activities.first?.id
        )
        let fields = [
            ActivityResponseField(
                key: "reason",
                values: ["실패해도 유지할 설명"]
            )
        ]
        let draft = ChapterLearningFeature.ActivityDraft(
            responseID: ActivityResponseID(
                rawValue: responseUUID.uuidString.lowercased()
            ),
            activityID: activityID,
            fields: fields
        )
        let clock = TestClock()
        let saver = RetryingResponseSaver()
        var state = ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: pageID
        )
        state.chapter = chapter
        let store = TestStore(initialState: state) {
            ChapterLearningFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.date.now = timestamp
            $0.uuid = .constant(responseUUID)
            $0.learningRecordClient.saveResponse = { response in
                try await saver.save(response)
            }
        }

        await store.send(.activityDraftChanged(
            activityID: activityID,
            fields: fields
        )) {
            $0.activityDrafts[activityID] = draft
            $0.activitySaveStates[activityID] = .pending
        }
        await clock.advance(by: .milliseconds(750))
        await store.receive(.activityAutosaveDelayElapsed(activityID)) {
            $0.activitySaveStates[activityID] = .saving
        }
        await store.receive(.activitySaveResponse(
            activityID: activityID,
            response: .failed(
                draft: draft,
                message: "테스트 자동 저장 실패"
            )
        )) {
            $0.activitySaveStates[activityID] = .persistenceError(
                "테스트 자동 저장 실패"
            )
        }

        await store.send(.activityRetryButtonTapped(activityID)) {
            $0.activitySaveStates[activityID] = .saving
        }
        await store.receive(.activitySaveResponse(
            activityID: activityID,
            response: .saved(draft: draft, savedAt: timestamp)
        )) {
            $0.activitySaveStates[activityID] = .saved(timestamp)
        }

        #expect(store.state.activityDrafts[activityID] == draft)
        let responses = await saver.responses()
        #expect(responses.count == 2)
        #expect(responses.allSatisfy { $0.id == draft.responseID })
    }

    @Test
    func structurallyInvalidDraftShowsValidationStateWithoutSaving() async throws {
        let chapter = try loadChapter()
        let pageID = try #require(chapter.progressPageIDs.first)
        let activityID = try #require(
            chapter.page(id: pageID)?.activities.first?.id
        )
        let draft = ChapterLearningFeature.ActivityDraft(
            responseID: ActivityResponseID(
                rawValue: responseUUID.uuidString.lowercased()
            ),
            activityID: activityID,
            fields: []
        )
        let clock = TestClock()
        var state = ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: pageID
        )
        state.chapter = chapter
        let store = TestStore(initialState: state) {
            ChapterLearningFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.uuid = .constant(responseUUID)
        }

        await store.send(.activityDraftChanged(
            activityID: activityID,
            fields: []
        )) {
            $0.activityDrafts[activityID] = draft
            $0.activitySaveStates[activityID] = .pending
        }
        await clock.advance(by: .milliseconds(750))
        await store.receive(.activityAutosaveDelayElapsed(activityID)) {
            $0.activitySaveStates[activityID] = .validationError(
                "저장할 입력이 없습니다."
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

private actor RetryingResponseSaver {
    private var recordedResponses: [ActivityResponse] = []

    func save(_ response: ActivityResponse) throws {
        recordedResponses.append(response)
        if recordedResponses.count == 1 {
            throw NSError(
                domain: "ChapterLearningFeatureTests",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "테스트 자동 저장 실패"
                ]
            )
        }
    }

    func responses() -> [ActivityResponse] {
        recordedResponses
    }
}
