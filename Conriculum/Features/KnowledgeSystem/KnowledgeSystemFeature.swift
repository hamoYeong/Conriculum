import ComposableArchitecture
import Foundation

@Reducer
struct KnowledgeSystemFeature {
    enum DisplayMode: String, CaseIterable, Equatable, Sendable {
        case shelves
        case network

        var title: String {
            switch self {
            case .shelves: "책장"
            case .network: "연결망"
            }
        }

        var systemImage: String {
            switch self {
            case .shelves: "books.vertical"
            case .network: "point.3.connected.trianglepath.dotted"
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        var snapshot: KnowledgeSystemSnapshot?
        var isLoading = false
        var loadErrorMessage: String?
        var searchQuery = ""
        var selectedCollectionID: KnowledgeCollectionID?
        var displayMode: DisplayMode = .shelves
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
        case displayModeChanged(DisplayMode)
        case conceptSelected(KnowledgeConceptID)
        case compareConceptRequested(KnowledgeConceptID)
        case conceptClosed(KnowledgeConceptID)
        case selectionCleared
        case homeButtonTapped
        case delegate(Delegate)
    }

    enum LoadResponse: Equatable, Sendable {
        case loaded(KnowledgeSystemSnapshot)
        case failed(message: String)
    }

    enum Delegate: Equatable {
        case homeRequested
    }

    @Dependency(\.knowledgeCatalogClient) var knowledgeCatalogClient
    @Dependency(\.personalKnowledgeClient) var personalKnowledgeClient

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
                        let catalog = try await knowledgeCatalogClient
                            .loadCatalog()
                        var revisions: [PersonalConceptRevision] = []
                        var relations: [PersonalKnowledgeRelation] = []
                        for concept in catalog.concepts {
                            async let conceptRevisions = personalKnowledgeClient
                                .loadRevisions(concept.id)
                            async let conceptRelations = personalKnowledgeClient
                                .loadRelations(concept.id)
                            revisions += try await conceptRevisions
                            relations += try await conceptRelations
                        }
                        let loadedRevisions = revisions
                        let loadedRelations = relations
                        let snapshot = await MainActor.run {
                            KnowledgeSystemSnapshotComposer().compose(
                                catalog: catalog,
                                revisions: loadedRevisions,
                                personalRelations: loadedRelations
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
                    snapshot.conceptItem(id: $0) != nil
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

            case let .displayModeChanged(mode):
                state.displayMode = mode
                return .none

            case let .conceptSelected(conceptID):
                guard state.snapshot?.conceptItem(id: conceptID) != nil
                else { return .none }
                state.selectedConceptIDs = [conceptID]
                return .none

            case let .compareConceptRequested(conceptID):
                guard state.snapshot?.conceptItem(id: conceptID) != nil,
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

            case .delegate:
                return .none
            }
        }
    }
}
