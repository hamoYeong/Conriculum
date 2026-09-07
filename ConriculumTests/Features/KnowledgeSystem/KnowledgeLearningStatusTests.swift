import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable import Conriculum

@MainActor
struct KnowledgeLearningStatusTests {
    private func chapter() throws -> V1Chapter {
        try ContentResourceDecoder().decode(V1Chapter.self, from: .chapter02)
    }

    @Test
    func threeStatesUseDistinctLabelsAndPersonalRelationsPromoteBothEnds() throws {
        let catalog = try ContentResourceDecoder().decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let relation = PersonalKnowledgeRelation(id: "own-link", sourceConceptID: "concept-value", targetConceptID: "concept-type",
            statement: "값을 쓰는 방법을 타입이 정한다", reason: "내가 설명한 연결", evidenceActivityID: "activity-test", createdAt: .distantPast)
        let snapshot = KnowledgeSystemSnapshotComposer().compose(catalog: catalog, revisions: [], personalRelations: [relation],
            learnedConceptIDs: ["concept-value", "concept-int"], personalConceptIDs: ["concept-string"])
        #expect(snapshot.conceptItem(id: "concept-bool")?.learningStatus == .unlearned)
        #expect(snapshot.conceptItem(id: "concept-int")?.learningStatus == .learned)
        for id in ["concept-value", "concept-type", "concept-string"] as [KnowledgeConceptID] {
            #expect(snapshot.conceptItem(id: id)?.learningStatus == .personal)
            #expect(snapshot.conceptItem(id: id)?.isLearned == true)
        }
        #expect(Set(KnowledgeSystemSnapshot.LearningStatus.allCases.map(\.systemImage)).count == 3)
        #expect(KnowledgeSystemSnapshot.LearningStatus.allCases.map(\.title) == ["아직 배우지 않음", "배운 지식", "내 지식"])
    }

    @Test
    func onlyPersonalLanguageNotChoicesConfidenceOrBlankAnswersPromotesKnowledge() throws {
        let chapter = try chapter()
        let page = try #require(chapter.progressPages.first)
        let exercise = try #require(page.sections.first { $0.content.tag == .choiceWithReason || $0.content.tag == .cardSorting || $0.content.tag == .matching })
        let id = try #require(exercise.activityID)
        func response(_ fields: [V1ActivityResponseField], date: Date = .distantPast) -> V1ActivityResponse {
            .init(id: "answer", activityID: id, pageID: page.id, fields: fields, recordedAt: date)
        }
        let choice = response([.init(key: "choice.test", values: ["option-a"])])
        #expect(LearnedKnowledgeResolver.personalConceptIDs(page: page, responses: [choice]).isEmpty)
        let explanation = response([.init(key: "reason", values: ["사용 목적이 달라서 다르게 표현한다"])])
        #expect(LearnedKnowledgeResolver.personalConceptIDs(page: page, responses: [explanation]) == V1LearningExposure.directConceptIDs(page: page))
        let cleared = response([.init(key: "reason", values: ["  "])], date: .distantFuture)
        #expect(LearnedKnowledgeResolver.personalConceptIDs(page: page, responses: [explanation, cleared]).isEmpty)
        #expect(LearnedKnowledgeResolver.personalConceptIDs(page: chapter.overview, responses: [explanation]).isEmpty)
    }

    @Test
    func visitsPersistWithoutAnswersDeduplicateAndSurviveReturningToEarlierPages() throws {
        let chapter = try chapter()
        let container = try PersistenceContainerFactory.inMemory()
        let store = UserDataStore(modelContainer: container)
        let pages = chapter.progressPages
        // An existing user's record, with no viewed evidence and no saved answer.
        try store.saveProgress(.init(chapterID: chapter.id, currentPageID: pages[3].id, completedPageIDs: [], updatedAt: .distantPast))
        try store.recordPageVisit(chapter: chapter, pageID: pages[3].id)
        try store.saveProgress(.init(chapterID: chapter.id, currentPageID: pages[0].id, completedPageIDs: [], updatedAt: .now))
        try store.recordPageVisit(chapter: chapter, pageID: pages[0].id)
        let restored = UserDataStore(modelContainer: container)
        for page in pages.prefix(4) {
            #expect(try restored.loadEvidence(pageID: page.id).filter { $0.kind == .viewed }.count == 1)
            #expect(try restored.loadResponses(pageID: page.id).isEmpty)
        }
        #expect(try restored.loadEvidence(pageID: pages[4].id).isEmpty)
        #expect(try restored.loadProgress(chapterID: chapter.id)?.completedPageIDs.isEmpty == true)
    }

    @Test
    func overviewAloneDoesNotUnlockLessons() throws {
        let chapter = try chapter()
        let store = UserDataStore(modelContainer: try PersistenceContainerFactory.inMemory())
        try store.recordPageVisit(chapter: chapter, pageID: chapter.overview.id)
        for page in chapter.progressPages {
            #expect(try store.loadEvidence(pageID: page.id).isEmpty)
        }
    }

    @Test
    func fileBackedLegacyStoreRetainsAnswersAndNewVisitsAfterReopening() throws {
        let chapter = try chapter()
        let page = chapter.progressPages[0]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("VisitPersistence-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("visits.store")
        func openStore() throws -> UserDataStore {
            let config = ModelConfiguration("VisitTest", schema: ConriculumPersistenceSchema.schema, url: url, cloudKitDatabase: .none)
            return UserDataStore(modelContainer: try ModelContainer(for: ConriculumPersistenceSchema.schema, configurations: [config]))
        }
        let response = V1ActivityResponse(id: "existing-answer", activityID: try #require(page.activities.first?.id),
            pageID: page.id, fields: [.init(key: "reason", values: ["기존 응답은 유지한다"])], recordedAt: .distantPast)
        do {
            let store = try openStore()
            try store.saveResponse(response)
            try store.saveProgress(.init(chapterID: chapter.id, currentPageID: page.id, completedPageIDs: [], updatedAt: .distantPast))
        }
        do {
            let store = try openStore()
            try store.recordPageVisit(chapter: chapter, pageID: page.id)
        }
        let restored = try openStore()
        #expect(try restored.loadResponses(pageID: page.id) == [response])
        #expect(try restored.loadEvidence(pageID: page.id).filter { $0.kind == .viewed }.count == 1)
    }

    @Test
    func exposureFailureIsVisibleAndCanBeRetriedWithoutLosingThePage() async throws {
        let chapter = try chapter()
        var initial = V1ChapterLearningFeature.State(chapterID: chapter.id, currentPageID: chapter.progressPageIDs[0])
        initial.chapter = chapter
        let store = TestStore(initialState: initial) { V1ChapterLearningFeature() } withDependencies: {
            $0.v1LearningRecordClient.recordPageVisit = { _, _ in
                throw NSError(domain: "visit-test", code: 1, userInfo: [NSLocalizedDescriptionKey: "열람 저장 실패"])
            }
        }
        store.timeout = .seconds(10)
        await store.send(.pagePresented)
        await store.receive(.pageVisitResponse(initial.currentPageID, "열람 저장 실패")) { $0.visitErrorMessage = "열람 저장 실패" }
        store.dependencies.v1LearningRecordClient.recordPageVisit = { _, _ in }
        await store.send(.pagePresented) { $0.visitErrorMessage = nil }
        await store.receive(.pageVisitResponse(initial.currentPageID, nil))
        #expect(store.state.currentPageID == initial.currentPageID)
    }

    @Test
    func pageVisitAloneUnlocksKnowledgeWhenTheBookshelfReloads() async throws {
        let chapter = try chapter()
        let page = chapter.progressPages[0]
        let catalog = try ContentResourceDecoder().decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let dataStore = UserDataStore(modelContainer: try PersistenceContainerFactory.inMemory())
        try dataStore.recordPageVisit(chapter: chapter, pageID: page.id)
        let expected = KnowledgeSystemSnapshotComposer().compose(catalog: catalog, revisions: [], personalRelations: [],
            learnedConceptIDs: V1LearningExposure.directConceptIDs(page: page))
        let store = TestStore(initialState: KnowledgeSystemFeature.State()) { KnowledgeSystemFeature() } withDependencies: {
            $0.v1CurriculumClient.loadChapters = { [chapter] }
            $0.v1KnowledgeCatalogClient.loadCatalog = { catalog }
            $0.v1LearningRecordClient = .live(store: dataStore)
            $0.v1PersonalKnowledgeClient.loadAllRevisions = { [] }
            $0.v1PersonalKnowledgeClient.loadAllRelations = { [] }
        }
        store.timeout = .seconds(10)
        await store.send(.retryButtonTapped) { $0.isLoading = true }
        await store.receive(.loadResponse(.loaded(expected))) {
            $0.isLoading = false
            $0.snapshot = expected
        }
        #expect(store.state.snapshot?.concepts.contains { $0.learningStatus == .learned } == true)
        #expect(store.state.snapshot?.concepts.contains { $0.learningStatus == .personal } == false)
    }
}
