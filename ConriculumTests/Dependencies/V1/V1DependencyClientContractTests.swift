import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct V1DependencyClientContractTests {
    @Test
    func featureTypechecksWithFourPurposeSpecificTestClients() async throws {
        let decoder = ContentResourceDecoder()
        let chapter = try decoder.decode(V1Chapter.self, from: .chapter02)
        let catalog = try decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let firstPage = try #require(chapter.pages.first)
        let firstConcept = try #require(catalog.concepts.first)

        let store = TestStore(initialState: ClientContractProbe.State()) {
            ClientContractProbe()
        } withDependencies: {
            $0.v1CurriculumClient = V1CurriculumClient(
                loadChapters: { [chapter] },
                loadChapter: { _ in chapter },
                loadPage: { _, _ in firstPage }
            )
            $0.v1KnowledgeCatalogClient = V1KnowledgeCatalogClient(
                loadCatalog: { catalog },
                loadConcept: { _ in firstConcept },
                loadRelations: { conceptID in
                    catalog.relations.filter {
                        $0.sourceConceptID == conceptID || $0.targetConceptID == conceptID
                    }
                }
            )
            $0.v1LearningRecordClient = V1LearningRecordClient(
                loadProgress: { _ in nil },
                saveProgress: { _ in },
                loadResponses: { _ in [] },
                saveResponse: { _ in },
                loadEvidence: { _ in [] },
                saveEvidence: { _ in },
                recordPageVisit: { _, _ in }
            )
            $0.v1PersonalKnowledgeClient = V1PersonalKnowledgeClient(
                loadAllRevisions: { [] },
                loadRevisions: { _ in [] },
                saveRevision: { _ in },
                loadAllRelations: { [] },
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
        let progress = try await V1LearningRecordClient.previewValue.loadProgress("chapter-02")
        let responses = try await V1LearningRecordClient.previewValue.loadResponses("chapter-02-page-01")
        let evidence = try await V1LearningRecordClient.previewValue.loadEvidence("chapter-02-page-01")
        let revisions = try await V1PersonalKnowledgeClient.previewValue.loadRevisions("concept-value")
        let relations = try await V1PersonalKnowledgeClient.previewValue.loadRelations("concept-value")
        let allRevisions = try await V1PersonalKnowledgeClient.previewValue.loadAllRevisions()
        let allRelations = try await V1PersonalKnowledgeClient.previewValue.loadAllRelations()

        #expect(progress == nil)
        #expect(responses.isEmpty)
        #expect(evidence.isEmpty)
        #expect(revisions.isEmpty)
        #expect(relations.isEmpty)
        #expect(allRevisions.isEmpty)
        #expect(allRelations.isEmpty)
    }

    @Test
    func clientErrorsExposeKoreanDescriptionsWithoutInternalDetails() {
        let technicalDetail = "internal.operation.identifier"
        let descriptions = [
            V1ContentClientError.chapterNotFound("missing-chapter")
                .localizedDescription,
            V1ContentClientError.invalidBundledContent(
                resource: technicalDetail,
                fieldPath: technicalDetail,
                message: technicalDetail
            ).localizedDescription,
            V1PersistenceClientError.loadFailed(
                operation: technicalDetail,
                message: technicalDetail
            ).localizedDescription,
            V1PersistenceClientError.invalidStoredData(
                record: technicalDetail,
                fieldPath: technicalDetail,
                message: technicalDetail
            ).localizedDescription,
        ]

        #expect(descriptions.allSatisfy { !$0.contains(technicalDetail) })
        #expect(descriptions.allSatisfy {
            $0.range(of: "[가-힣]", options: .regularExpression) != nil
        })
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

    @Dependency(\.v1CurriculumClient) var v1CurriculumClient
    @Dependency(\.v1KnowledgeCatalogClient) var v1KnowledgeCatalogClient
    @Dependency(\.v1LearningRecordClient) var v1LearningRecordClient
    @Dependency(\.v1PersonalKnowledgeClient) var v1PersonalKnowledgeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .probe:
                return .run { send in
                    do {
                        let chapter = try await v1CurriculumClient.loadChapter("chapter-02")
                        let page = try await v1CurriculumClient.loadPage(chapter.id, "chapter-02-page-01")
                        _ = try await v1KnowledgeCatalogClient.loadCatalog()
                        let concept = try await v1KnowledgeCatalogClient.loadConcept("concept-value")
                        _ = try await v1KnowledgeCatalogClient.loadRelations(concept.id)
                        let progress = try await v1LearningRecordClient.loadProgress(chapter.id)
                        _ = try await v1LearningRecordClient.loadResponses(page.id)
                        _ = try await v1LearningRecordClient.loadEvidence(page.id)
                        let revisions = try await v1PersonalKnowledgeClient.loadRevisions(concept.id)
                        _ = try await v1PersonalKnowledgeClient.loadRelations(concept.id)
                        _ = try await v1PersonalKnowledgeClient.loadAllRevisions()
                        _ = try await v1PersonalKnowledgeClient.loadAllRelations()

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
