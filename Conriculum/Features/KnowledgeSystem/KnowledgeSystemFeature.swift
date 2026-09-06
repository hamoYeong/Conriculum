import ComposableArchitecture
import Foundation

@Reducer
struct KnowledgeSystemFeature {
    @ObservableState
    struct State: Equatable {
        var contentVersion: ContentVersion = .v1
        var snapshot: KnowledgeSystemSnapshot?
        var isLoading = false
        var loadErrorMessage: String?
        var searchQuery = ""
        var selectedCollectionID: KnowledgeCollectionID?
        var selectedConceptIDs: [KnowledgeConceptID] = []

        var selectedConcepts: [KnowledgeSystemSnapshot.ConceptItem] {
            guard let snapshot else { return [] }
            return selectedConceptIDs.compactMap(snapshot.conceptItem(id:))
        }

        var visibleConcepts: [KnowledgeSystemSnapshot.ConceptItem] {
            guard let snapshot else { return [] }
            let normalizedQuery = searchQuery
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedLowercase

            return snapshot.concepts.filter { item in
                let belongsToSelectedCollection = selectedCollectionID.map {
                    item.collectionID == $0
                } ?? true
                guard belongsToSelectedCollection else { return false }
                guard normalizedQuery.isEmpty == false else { return true }

                let searchableText = [
                    item.concept.title,
                    item.concept.definition,
                    item.concept.essentialQuestion,
                    item.concept.judgmentQuestions.joined(separator: " "),
                    item.concept.examples.joined(separator: " "),
                    item.concept.misconceptions.joined(separator: " "),
                    (item.concept.revisitPages ?? []).map {
                        "\($0.chapterTitle) \($0.pageTitle) \($0.connection)"
                    }.joined(separator: " "),
                    item.latestRevision?.personalTitle ?? "",
                    item.latestRevision?.explanation ?? "",
                ]
                .joined(separator: " ")
                .localizedLowercase
                return searchableText.localizedStandardContains(
                    normalizedQuery
                )
            }
        }

        var visibleBaseRelations: [KnowledgeRelation] {
            guard let snapshot else { return [] }
            let visibleIDs = Set(visibleConcepts.map(\.id))
            return snapshot.baseRelations.filter {
                visibleIDs.contains($0.sourceConceptID)
                    && visibleIDs.contains($0.targetConceptID)
            }
        }
    }

    enum Action: Equatable {
        case task
        case retryButtonTapped
        case loadResponse(LoadResponse)
        case searchQueryChanged(String)
        case collectionSelected(KnowledgeCollectionID?)
        case conceptSelected(KnowledgeConceptID)
        case compareConceptRequested(KnowledgeConceptID)
        case conceptClosed(KnowledgeConceptID)
        case selectionCleared
        case homeButtonTapped
        case learningPageTapped(KnowledgeLearningReference)
        case delegate(Delegate)
    }

    enum LoadResponse: Equatable, Sendable {
        case loaded(KnowledgeSystemSnapshot)
        case failed(message: String)
    }

    enum Delegate: Equatable {
        case homeRequested
        case learningRequested(ChapterID, LearningPageID)
        case v2LearningRequested(String)
    }

    @Dependency(\.knowledgeCatalogClient) var knowledgeCatalogClient
    @Dependency(\.personalKnowledgeClient) var personalKnowledgeClient
    @Dependency(\.curriculumClient) var curriculumClient
    @Dependency(\.learningRecordClient) var learningRecordClient
    @Dependency(\.v2ContentClient) var v2ContentClient
    @Dependency(\.v2ProgressClient) var v2ProgressClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard state.snapshot == nil, !state.isLoading else {
                    return .none
                }
                return .send(.retryButtonTapped)

            case .retryButtonTapped:
                state.isLoading = true
                state.loadErrorMessage = nil
                if state.contentVersion == .v2 {
                    return .run { send in
                        do {
                            async let catalogRequest = v2ContentClient
                                .loadKnowledgeCatalog()
                            async let progressRequest = v2ProgressClient.load()
                            let catalog = try await catalogRequest
                            let progress = try await progressRequest
                            let learnedPageIDs = progress.completedPageIDs
                            let learnedConceptIDs = Set(
                                catalog.concepts.compactMap { concept in
                                    let wasLearned = concept.revisitPages?.contains {
                                        learnedPageIDs.contains($0.pageID.rawValue)
                                    } == true
                                    return wasLearned ? concept.id : nil
                                }
                            )
                            let snapshot = await MainActor.run {
                                KnowledgeSystemSnapshotComposer().compose(
                                    catalog: catalog,
                                    revisions: [],
                                    personalRelations: [],
                                    learnedConceptIDs: learnedConceptIDs
                                )
                            }
                            await send(.loadResponse(.loaded(snapshot)))
                        } catch {
                            await send(.loadResponse(.failed(
                                message: error.localizedDescription
                            )))
                        }
                    }
                    .cancellable(
                        id: "KnowledgeSystemFeature.v2Load",
                        cancelInFlight: true
                    )
                }
                return .run { send in
                    do {
                        async let catalog = knowledgeCatalogClient.loadCatalog()
                        async let revisions = personalKnowledgeClient
                            .loadAllRevisions()
                        async let relations = personalKnowledgeClient
                            .loadAllRelations()
                        let loadedCatalog = try await catalog
                        let loadedRevisions = try await revisions
                        let loadedRelations = try await relations
                        let chapters = try await curriculumClient.loadChapters()
                        var learnedIDs = Set<KnowledgeConceptID>()
                        var personalIDs = Set<KnowledgeConceptID>()
                        for chapter in chapters {
                            let progress = try await learningRecordClient.loadProgress(chapter.id)
                            let historicalIDs = await LearningExposure.historicalPageIDs(chapter: chapter, progress: progress)
                            for page in chapter.pages {
                                let responses = try await learningRecordClient.loadResponses(page.id)
                                let evidence = try await learningRecordClient.loadEvidence(page.id)
                                if historicalIDs.contains(page.id) || evidence.contains(where: { $0.kind == .viewed && $0.pageID == page.id }) {
                                    learnedIDs.formUnion(await LearningExposure.directConceptIDs(page: page))
                                }
                                learnedIDs.formUnion(await LearnedKnowledgeResolver.conceptIDs(
                                    page: page, responses: responses
                                ))
                                personalIDs.formUnion(await LearnedKnowledgeResolver.personalConceptIDs(page: page, responses: responses))
                            }
                        }
                        let loadedLearnedIDs = learnedIDs
                        let loadedPersonalIDs = personalIDs
                        let snapshot = await MainActor.run {
                            KnowledgeSystemSnapshotComposer().compose(
                                catalog: loadedCatalog,
                                revisions: loadedRevisions,
                                personalRelations: loadedRelations,
                                learnedConceptIDs: loadedLearnedIDs,
                                personalConceptIDs: loadedPersonalIDs
                            )
                        }
                        await send(.loadResponse(.loaded(snapshot)))
                    } catch {
                        await send(.loadResponse(.failed(
                            message: error.localizedDescription
                        )))
                    }
                }
                .cancellable(
                    id: "KnowledgeSystemFeature.load",
                    cancelInFlight: true
                )

            case let .loadResponse(.loaded(snapshot)):
                state.isLoading = false
                state.loadErrorMessage = nil
                state.snapshot = snapshot
                state.selectedConceptIDs = state.selectedConceptIDs.filter {
                    snapshot.conceptItem(id: $0)?.isLearned == true
                }
                if let selectedCollectionID = state.selectedCollectionID,
                   snapshot.collection(id: selectedCollectionID) == nil {
                    state.selectedCollectionID = nil
                }
                return .none

            case let .loadResponse(.failed(message)):
                state.isLoading = false
                state.loadErrorMessage = message
                return .none

            case let .searchQueryChanged(query):
                state.searchQuery = query
                return .none

            case let .collectionSelected(collectionID):
                state.selectedCollectionID = collectionID
                return .none

            case let .conceptSelected(conceptID):
                guard state.snapshot?.conceptItem(id: conceptID)?.isLearned == true
                else { return .none }
                state.selectedConceptIDs = [conceptID]
                return .none

            case let .compareConceptRequested(conceptID):
                guard state.snapshot?.conceptItem(id: conceptID)?.isLearned == true,
                      !state.selectedConceptIDs.contains(conceptID)
                else { return .none }
                switch state.selectedConceptIDs.count {
                case 0:
                    state.selectedConceptIDs = [conceptID]
                case 1:
                    state.selectedConceptIDs.append(conceptID)
                default:
                    state.selectedConceptIDs[1] = conceptID
                }
                return .none

            case let .conceptClosed(conceptID):
                state.selectedConceptIDs.removeAll { $0 == conceptID }
                return .none

            case .selectionCleared:
                state.selectedConceptIDs = []
                return .none

            case .homeButtonTapped:
                return .send(.delegate(.homeRequested))

            case let .learningPageTapped(reference):
                if state.contentVersion == .v2 {
                    return .send(.delegate(.v2LearningRequested(
                        reference.pageID.rawValue
                    )))
                }
                return .send(.delegate(.learningRequested(
                    reference.chapterID,
                    reference.pageID
                )))

            case .delegate:
                return .none
            }
        }
    }
}
