import ComposableArchitecture
import Foundation

@Reducer
struct KnowledgeSystemFeature {
    @ObservableState
    struct State: Equatable {
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
                return searchableText.localizedStandardContains(normalizedQuery)
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
        case learningRequested(String)
    }

    @Dependency(\.contentClient) var contentClient
    @Dependency(\.progressClient) var progressClient

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
                return .run { send in
                    do {
                        async let catalogRequest = contentClient.loadKnowledgeCatalog()
                        async let progressRequest = progressClient.load()
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
                    id: "KnowledgeSystemFeature.contentLoad",
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
                return .send(.delegate(.learningRequested(reference.pageID.rawValue)))

            case .delegate:
                return .none
            }
        }
    }
}
