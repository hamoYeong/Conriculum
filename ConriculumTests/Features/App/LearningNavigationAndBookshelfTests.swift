import ComposableArchitecture
import Foundation
import Testing
@testable import Conriculum

@MainActor
struct LearningNavigationAndBookshelfTests {
    @Test
    func completionOpensChapterThreeMapThroughTheWholeReducerChain() async throws {
        let chapter = try ContentResourceDecoder().decode(Chapter.self, from: .chapter02)
        let next = try ContentResourceDecoder().decode(Chapter.self, from: .chapter(stageNumber: 1, chapterNumber: 3))
        var initial = AppFeature.State()
        initial.route = .learningWorkspace(chapterID: chapter.id)
        initial.workspace = .init(chapterID: chapter.id, pageID: try #require(chapter.progressPageIDs.last))
        initial.workspace?.chapter.chapter = chapter
        initial.workspace?.chapter.isShowingCompletionSummary = true
        let savedProgress = LockIsolated<[LearningProgress]>([])
        let store = TestStore(initialState: initial) { AppFeature() } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 100)
            $0.curriculumClient.loadChapters = { [chapter, next] }
            $0.learningRecordClient.loadProgress = { _ in nil }
            $0.learningRecordClient.saveProgress = { progress in savedProgress.withValue { $0.append(progress) } }
        }
        store.timeout = .seconds(10)
        await store.send(.workspace(.chapter(.nextChapterButtonTapped))) {
            $0.workspace?.chapter.isSavingNavigation = true
        }
        await store.receive(.workspace(.chapter(.nextChapterResolved(next.id, next.overview.id)))) {
            $0.workspace?.chapter.isSavingNavigation = false
        }
        await store.receive(.workspace(.chapter(.delegate(.chapterRequested(next.id, next.overview.id)))))
        await store.receive(.workspace(.delegate(.chapterRequested(next.id, next.overview.id)))) {
            $0.route = .learningWorkspace(chapterID: next.id)
            $0.workspace = .init(chapterID: next.id, pageID: next.overview.id)
        }
        #expect(savedProgress.value.first?.chapterID == next.id)
        #expect(savedProgress.value.first?.currentPageID == next.overview.id)
    }

    @Test
    func missingNextChapterLeavesSummaryAvailableForRetry() async throws {
        let chapter = try ContentResourceDecoder().decode(Chapter.self, from: .chapter02)
        var initial = ChapterLearningFeature.State(chapterID: chapter.id, currentPageID: try #require(chapter.progressPageIDs.last))
        initial.chapter = chapter
        initial.isShowingCompletionSummary = true
        let store = TestStore(initialState: initial) { ChapterLearningFeature() } withDependencies: {
            $0.curriculumClient.loadChapters = { [chapter] }
        }
        await store.send(.nextChapterButtonTapped) { $0.isSavingNavigation = true }
        await store.receive(.nextChapterFailed("다음 챕터의 콘텐츠가 아직 준비되지 않았습니다.")) {
            $0.isSavingNavigation = false
            $0.navigationErrorMessage = "다음 챕터의 콘텐츠가 아직 준비되지 않았습니다."
        }
        #expect(store.state.isShowingCompletionSummary)
    }

    @Test
    func bookshelfUnlockRequiresRealLessonInputAndNotOverviewOrCompass() throws {
        let chapter = try ContentResourceDecoder().decode(Chapter.self, from: .chapter02)
        let page = try #require(chapter.progressPages.first)
        let exercise = try #require(page.sections.first { $0.activityID != nil && $0.content.tag != .learningCompass })
        let activityID = try #require(exercise.activityID)
        let response = ActivityResponse(id: "test-attempt", activityID: activityID, pageID: page.id,
            fields: [.init(key: "reason", values: ["값이 쓰이는 의미를 비교했다"])], recordedAt: .distantPast)
        let actual = LearnedKnowledgeResolver.conceptIDs(page: page, responses: [response])
        #expect(actual == Set(page.knowledgeLinks.filter { $0.role == .primary || $0.role == .supporting }.map(\.conceptID)))
        #expect(!actual.isEmpty)
        #expect(LearnedKnowledgeResolver.conceptIDs(page: chapter.overview, responses: [response]).isEmpty)
        #expect(LearnedKnowledgeResolver.conceptIDs(page: page, responses: []).isEmpty)
        let blank = ActivityResponse(id: response.id, activityID: activityID, pageID: page.id,
            fields: [.init(key: "reason", values: [" \n "])], recordedAt: .distantFuture)
        #expect(LearnedKnowledgeResolver.conceptIDs(page: page, responses: [response, blank]).isEmpty)
        let compass = try #require(page.sections.first { $0.content.tag == .learningCompass }?.activityID)
        let guess = ActivityResponse(id: "guess", activityID: compass, pageID: page.id,
            fields: response.fields, recordedAt: .distantPast)
        #expect(LearnedKnowledgeResolver.conceptIDs(page: page, responses: [guess]).isEmpty)
    }

    @Test
    func lockedKnowledgeCannotOpenViaSelectionOrComparison() async throws {
        let catalog = try ContentResourceDecoder().decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let snapshot = KnowledgeSystemSnapshotComposer().compose(catalog: catalog, revisions: [], personalRelations: [])
        let store = TestStore(initialState: KnowledgeSystemFeature.State(snapshot: snapshot)) { KnowledgeSystemFeature() }
        await store.send(.conceptSelected("concept-type"))
        await store.send(.compareConceptRequested("concept-value"))
        #expect(store.state.selectedConceptIDs.isEmpty)
    }

    @Test
    func relationHighlightPreservesTypesInBothDirections() throws {
        let catalog = try ContentResourceDecoder().decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let snapshot = KnowledgeSystemSnapshotComposer().compose(catalog: catalog, revisions: [], personalRelations: [])
        for relation in snapshot.baseRelations {
            #expect(snapshot.relationKinds(from: [relation.sourceConceptID], to: relation.targetConceptID).contains(relation.kind))
            #expect(snapshot.relationKinds(from: [relation.targetConceptID], to: relation.sourceConceptID).contains(relation.kind))
        }
        #expect(snapshot.relationKinds(from: ["concept-type"], to: "concept-type").isEmpty)
    }
}
