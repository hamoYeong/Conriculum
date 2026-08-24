import ComposableArchitecture
import Testing

@testable import Conriculum

@MainActor
struct DependencyClientContractTests {
    @Test
    func featureTypechecksWithFourPurposeSpecificTestClients() async throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let firstPage = try #require(chapter.pages.first)
        let firstConcept = try #require(catalog.concepts.first)

        let store = TestStore(initialState: ClientContractProbe.State()) {
            ClientContractProbe()
        } withDependencies: {
            $0.curriculumClient = CurriculumClient(
                loadChapter: { _ in chapter },
                loadPage: { _, _ in firstPage }
            )
            $0.knowledgeCatalogClient = KnowledgeCatalogClient(
                loadCatalog: { catalog },
                loadConcept: { _ in firstConcept },
                loadRelations: { conceptID in
                    catalog.relations.filter {
                        $0.sourceConceptID == conceptID || $0.targetConceptID == conceptID
                    }
                }
            )
            $0.learningRecordClient = LearningRecordClient(
                loadProgress: { _ in nil },
                saveProgress: { _ in },
                loadResponses: { _ in [] },
                saveResponse: { _ in },
                loadEvidence: { _ in [] },
                saveEvidence: { _ in }
            )
            $0.personalKnowledgeClient = PersonalKnowledgeClient(
                loadRevisions: { _ in [] },
                saveRevision: { _ in },
                loadRelations: { _ in [] },
                saveRelation: { _ in }
            )
        }

        await store.send(.probe)
        await store.receive(
            .loaded(
                chapterID: chapter.id,
                pageID: firstPage.id,
                conceptID: firstConcept.id,
                hasProgress: false,
                revisionCount: 0
            )
        ) {
            $0.chapterID = chapter.id
            $0.pageID = firstPage.id
            $0.conceptID = firstConcept.id
            $0.hasProgress = false
            $0.revisionCount = 0
        }
    }

    @Test
    func previewRecordClientsProvideInMemoryEmptyValues() async throws {
        let progress = try await LearningRecordClient.previewValue.loadProgress("chapter-02")
        let responses = try await LearningRecordClient.previewValue.loadResponses("chapter-02-page-01")
        let evidence = try await LearningRecordClient.previewValue.loadEvidence("chapter-02-page-01")
        let revisions = try await PersonalKnowledgeClient.previewValue.loadRevisions("concept-value")
        let relations = try await PersonalKnowledgeClient.previewValue.loadRelations("concept-value")

        #expect(progress == nil)
        #expect(responses.isEmpty)
        #expect(evidence.isEmpty)
        #expect(revisions.isEmpty)
        #expect(relations.isEmpty)
    }
}

@Reducer
private struct ClientContractProbe {
    @ObservableState
    struct State: Equatable {
        var chapterID: ChapterID?
        var pageID: LearningPageID?
        var conceptID: KnowledgeConceptID?
        var hasProgress = false
        var revisionCount = 0
    }

    enum Action: Equatable {
        case probe
        case loaded(
            chapterID: ChapterID,
            pageID: LearningPageID,
            conceptID: KnowledgeConceptID,
            hasProgress: Bool,
            revisionCount: Int
        )
        case failed
    }

    @Dependency(\.curriculumClient) var curriculumClient
    @Dependency(\.knowledgeCatalogClient) var knowledgeCatalogClient
    @Dependency(\.learningRecordClient) var learningRecordClient
    @Dependency(\.personalKnowledgeClient) var personalKnowledgeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .probe:
                return .run { send in
                    do {
                        let chapter = try await curriculumClient.loadChapter("chapter-02")
                        let page = try await curriculumClient.loadPage(chapter.id, "chapter-02-page-01")
                        _ = try await knowledgeCatalogClient.loadCatalog()
                        let concept = try await knowledgeCatalogClient.loadConcept("concept-value")
                        _ = try await knowledgeCatalogClient.loadRelations(concept.id)
                        let progress = try await learningRecordClient.loadProgress(chapter.id)
                        _ = try await learningRecordClient.loadResponses(page.id)
                        _ = try await learningRecordClient.loadEvidence(page.id)
                        let revisions = try await personalKnowledgeClient.loadRevisions(concept.id)
                        _ = try await personalKnowledgeClient.loadRelations(concept.id)

                        await send(.loaded(
                            chapterID: chapter.id,
                            pageID: page.id,
                            conceptID: concept.id,
                            hasProgress: progress != nil,
                            revisionCount: revisions.count
                        ))
                    } catch {
                        await send(.failed)
                    }
                }

            case let .loaded(chapterID, pageID, conceptID, hasProgress, revisionCount):
                state.chapterID = chapterID
                state.pageID = pageID
                state.conceptID = conceptID
                state.hasProgress = hasProgress
                state.revisionCount = revisionCount
                return .none

            case .failed:
                return .none
            }
        }
    }
}
