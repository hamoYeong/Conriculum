import ComposableArchitecture
import Foundation

@Reducer
struct KnowledgeContextFeature {
    enum ReloadReason: Equatable, Sendable {
        case initial
        case pageChanged
        case personalizationSaved
    }

    @ObservableState
    struct State: Equatable {
        let chapterID: ChapterID
        var currentPageID: LearningPageID
        var snapshot: KnowledgeContextSnapshot?
        var isLoading = false
        var loadErrorMessage: String?
        var lastReloadReason: ReloadReason?
        var reloadRequestCount = 0

        init(
            chapterID: ChapterID,
            currentPageID: LearningPageID,
            snapshot: KnowledgeContextSnapshot? = nil
        ) {
            self.chapterID = chapterID
            self.currentPageID = currentPageID
            self.snapshot = snapshot
        }
    }

    enum Action: Equatable {
        case task
        case pageChanged(LearningPageID)
        case personalizationSaved
        case reloadRequested(ReloadReason)
        case loadResponse(LoadResponse)
        case delegate(Delegate)
    }

    enum LoadResponse: Equatable, Sendable {
        case loaded(KnowledgeContextSnapshot)
        case failed(pageID: LearningPageID, message: String)
    }

    enum Delegate: Equatable {
        case personalizationSaved
    }

    @Dependency(\.curriculumClient) var curriculumClient
    @Dependency(\.knowledgeCatalogClient) var knowledgeCatalogClient
    @Dependency(\.personalKnowledgeClient) var personalKnowledgeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard state.snapshot == nil, !state.isLoading else {
                    return .none
                }
                return .send(.reloadRequested(.initial))

            case let .pageChanged(pageID):
                state.currentPageID = pageID
                state.snapshot = nil
                state.loadErrorMessage = nil
                return .send(.reloadRequested(.pageChanged))

            case .personalizationSaved:
                return .send(.delegate(.personalizationSaved))

            case let .reloadRequested(reason):
                state.lastReloadReason = reason
                state.reloadRequestCount += 1
                state.isLoading = true
                state.loadErrorMessage = nil
                let chapterID = state.chapterID
                let pageID = state.currentPageID

                return .run { send in
                    do {
                        async let chapter = curriculumClient.loadChapter(
                            chapterID
                        )
                        async let catalog = knowledgeCatalogClient.loadCatalog()
                        let loadedChapter = try await chapter
                        let loadedCatalog = try await catalog
                        let conceptIDs = await MainActor.run {
                            KnowledgeContextSnapshotComposer
                                .chapterConceptIDs(in: loadedChapter)
                        }
                        var revisions: [PersonalConceptRevision] = []
                        for conceptID in conceptIDs {
                            revisions += try await personalKnowledgeClient
                                .loadRevisions(conceptID)
                        }
                        let loadedRevisions = revisions
                        let snapshot = try await MainActor.run {
                            try KnowledgeContextSnapshotComposer().compose(
                                chapter: loadedChapter,
                                catalog: loadedCatalog,
                                pageID: pageID,
                                revisions: loadedRevisions
                            )
                        }
                        await send(.loadResponse(.loaded(snapshot)))
                    } catch {
                        await send(.loadResponse(.failed(
                            pageID: pageID,
                            message: error.localizedDescription
                        )))
                    }
                }
                .cancellable(
                    id: "KnowledgeContextFeature.load",
                    cancelInFlight: true
                )

            case let .loadResponse(.loaded(snapshot)):
                guard snapshot.pageID == state.currentPageID else {
                    return .none
                }
                state.snapshot = snapshot
                state.isLoading = false
                state.loadErrorMessage = nil
                return .none

            case let .loadResponse(.failed(pageID, message)):
                guard pageID == state.currentPageID else { return .none }
                state.isLoading = false
                state.loadErrorMessage = message
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
