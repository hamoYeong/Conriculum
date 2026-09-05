import Foundation
import SwiftData
import Testing
@testable import Conriculum

@MainActor
struct LiveDependencyClientTests {
    @Test
    func bundledClientsLoadValidatedChapterAndKnowledge() async throws {
        let contentStore = BundledContentStore()
        let curriculumClient = CurriculumClient.live(store: contentStore)
        let knowledgeClient = KnowledgeCatalogClient.live(store: contentStore)

        let chapters = try await curriculumClient.loadChapters()
        let chapter = try await curriculumClient.loadChapter("chapter-02")
        let overview = try await curriculumClient.loadPage(
            chapter.id,
            chapter.overview.id
        )
        let firstLesson = try #require(chapter.pages.first)
        let loadedLesson = try await curriculumClient.loadPage(
            chapter.id,
            firstLesson.id
        )
        let catalog = try await knowledgeClient.loadCatalog()
        let firstConcept = try #require(catalog.concepts.first)
        let loadedConcept = try await knowledgeClient.loadConcept(firstConcept.id)
        let relations = try await knowledgeClient.loadRelations(firstConcept.id)

        #expect(chapters.map(\.id) == ["chapter-02", "chapter-03", "chapter-04"])
        #expect(chapter.progressDenominator == chapter.progressPages.count)
        #expect(overview.kind == .overview)
        #expect(loadedLesson == firstLesson)
        #expect(loadedConcept == firstConcept)
        #expect(relations.allSatisfy {
            $0.sourceConceptID == firstConcept.id || $0.targetConceptID == firstConcept.id
        })
    }

    @Test
    func localProfileIDIsCreatedOnceAndReused() async throws {
        let environment = try PersistenceEnvironmentRegistry.makeInMemoryEnvironment()
        let firstID = try environment.userDataStore.localProfileID()
        let secondID = try environment.userDataStore.localProfileID()

        let relaunchedStore = UserDataStore(
            modelContainer: environment.modelContainer
        )
        let relaunchedID = try relaunchedStore.localProfileID()

        let context = ModelContext(environment.modelContainer)
        let profileCount = try context.fetchCount(
            FetchDescriptor<LocalProfileRecord>()
        )

        #expect(firstID == secondID)
        #expect(relaunchedID == firstID)
        #expect(profileCount == 1)
    }

    @Test
    func appAssemblyInjectsClientsBackedByItsRootContainer() async throws {
        let assembly = try AppAssembly.inMemory()
        let progress = LearningProgress(
            chapterID: "chapter-02",
            currentPageID: "chapter-02-page-01",
            completedPageIDs: [],
            updatedAt: Date(timeIntervalSince1970: 1_725_782_400)
        )

        try await assembly.learningRecordClient.saveProgress(progress)

        let reassembledStore = UserDataStore(
            modelContainer: assembly.modelContainer
        )
        let recoveredProgress = try reassembledStore.loadProgress(
            chapterID: progress.chapterID
        )

        #expect(recoveredProgress == progress)
    }
}
