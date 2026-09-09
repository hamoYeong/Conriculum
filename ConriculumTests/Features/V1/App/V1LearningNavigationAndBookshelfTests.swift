import ComposableArchitecture
import Foundation
import Testing
@testable import Conriculum

@MainActor
struct V1LearningNavigationAndBookshelfTests {
    @Test
    func completionOpensChapterThreeMapThroughTheWholeReducerChain() async throws {
        let chapter = try ContentResourceDecoder().decode(V1Chapter.self, from: .chapter02)
        let next = try ContentResourceDecoder().decode(V1Chapter.self, from: .chapter(stageNumber: 1, chapterNumber: 3))
        var initial = AppFeature.State()
        initial.route = .v1Learning(chapterID: chapter.id)
        initial.v1Workspace = .init(chapterID: chapter.id, pageID: try #require(chapter.progressPageIDs.last))
        initial.v1Workspace?.chapter.chapter = chapter
        initial.v1Workspace?.chapter.isShowingCompletionSummary = true
        let savedProgress = LockIsolated<[V1LearningProgress]>([])
        let store = TestStore(initialState: initial) { AppFeature() } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 100)
            $0.v1CurriculumClient.loadChapters = { [chapter, next] }
            $0.v1LearningRecordClient.loadProgress = { _ in nil }
            $0.v1LearningRecordClient.saveProgress = { progress in savedProgress.withValue { $0.append(progress) } }
        }
        store.timeout = .seconds(10)
        await store.send(.v1Workspace(.chapter(.nextChapterButtonTapped))) {
            $0.v1Workspace?.chapter.isSavingNavigation = true
        }
        await store.receive(.v1Workspace(.chapter(.nextChapterResolved(next.id, next.overview.id)))) {
            $0.v1Workspace?.chapter.isSavingNavigation = false
        }
        await store.receive(.v1Workspace(.chapter(.delegate(.v1ChapterRequested(next.id, next.overview.id)))))
        await store.receive(.v1Workspace(.delegate(.v1ChapterRequested(next.id, next.overview.id)))) {
            $0.route = .v1Learning(chapterID: next.id)
            $0.v1Workspace = .init(chapterID: next.id, pageID: next.overview.id)
        }
        #expect(savedProgress.value.first?.chapterID == next.id)
        #expect(savedProgress.value.first?.currentPageID == next.overview.id)
    }

    @Test
    func missingNextChapterLeavesSummaryAvailableForRetry() async throws {
        let chapter = try ContentResourceDecoder().decode(V1Chapter.self, from: .chapter02)
        var initial = V1ChapterLearningFeature.State(chapterID: chapter.id, currentPageID: try #require(chapter.progressPageIDs.last))
        initial.chapter = chapter
        initial.isShowingCompletionSummary = true
        let store = TestStore(initialState: initial) { V1ChapterLearningFeature() } withDependencies: {
            $0.v1CurriculumClient.loadChapters = { [chapter] }
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
        let chapter = try ContentResourceDecoder().decode(V1Chapter.self, from: .chapter02)
        let page = try #require(chapter.progressPages.first)
        let exercise = try #require(page.sections.first { $0.activityID != nil && $0.content.tag != .learningCompass })
        let activityID = try #require(exercise.activityID)
        let response = V1ActivityResponse(id: "test-attempt", activityID: activityID, pageID: page.id,
            fields: [.init(key: "reason", values: ["값이 쓰이는 의미를 비교했다"])], recordedAt: .distantPast)
        let actual = V1LearnedKnowledgeResolver.conceptIDs(page: page, responses: [response])
        #expect(actual == Set(page.knowledgeLinks.filter { $0.role == .primary || $0.role == .supporting }.map(\.conceptID)))
        #expect(!actual.isEmpty)
        #expect(V1LearnedKnowledgeResolver.conceptIDs(page: chapter.overview, responses: [response]).isEmpty)
        #expect(V1LearnedKnowledgeResolver.conceptIDs(page: page, responses: []).isEmpty)
        let blank = V1ActivityResponse(id: response.id, activityID: activityID, pageID: page.id,
            fields: [.init(key: "reason", values: [" \n "])], recordedAt: .distantFuture)
        #expect(V1LearnedKnowledgeResolver.conceptIDs(page: page, responses: [response, blank]).isEmpty)
        let compass = try #require(page.sections.first { $0.content.tag == .learningCompass }?.activityID)
        let guess = V1ActivityResponse(id: "guess", activityID: compass, pageID: page.id,
            fields: response.fields, recordedAt: .distantPast)
        #expect(V1LearnedKnowledgeResolver.conceptIDs(page: page, responses: [guess]).isEmpty)
    }

    @Test
    func lockedKnowledgeCannotOpenViaSelectionOrComparison() async throws {
        let catalog = try ContentResourceDecoder().decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let v1Snapshot = KnowledgeSystemSnapshotComposer().compose(catalog: catalog, revisions: [], personalRelations: [])
        let store = TestStore(initialState: KnowledgeSystemFeature.State(snapshot: v1Snapshot)) { KnowledgeSystemFeature() }
        await store.send(.conceptSelected("concept-type"))
        await store.send(.compareConceptRequested("concept-value"))
        #expect(store.state.selectedConceptIDs.isEmpty)
    }

    @Test
    func relationHighlightPreservesTypesInBothDirections() throws {
        let catalog = try ContentResourceDecoder().decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let v1Snapshot = KnowledgeSystemSnapshotComposer().compose(catalog: catalog, revisions: [], personalRelations: [])
        for relation in v1Snapshot.baseRelations {
            #expect(v1Snapshot.relationKinds(from: [relation.sourceConceptID], to: relation.targetConceptID).contains(relation.kind))
            #expect(v1Snapshot.relationKinds(from: [relation.targetConceptID], to: relation.sourceConceptID).contains(relation.kind))
        }
        #expect(v1Snapshot.relationKinds(from: ["concept-type"], to: "concept-type").isEmpty)
    }
}
