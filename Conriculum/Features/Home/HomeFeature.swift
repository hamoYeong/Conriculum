import ComposableArchitecture
import Foundation

@Reducer
struct HomeFeature {
    struct ChapterEntry: Equatable, Sendable {
        let chapterID: ChapterID
        let startPageID: LearningPageID
        let resumePageID: LearningPageID?
    }

    @ObservableState
    struct State: Equatable {
        var isLoading = false
        var chapterEntry: ChapterEntry?
        var snapshot: HomeSnapshot?
        var placeholderSnapshot: HomeSnapshot?
        var loadErrorMessage: String?

        init(
            snapshot: HomeSnapshot? = nil,
            usesSnapshotAsPlaceholder: Bool = false
        ) {
            self.snapshot = snapshot
            placeholderSnapshot = usesSnapshotAsPlaceholder ? snapshot : nil
            chapterEntry = snapshot.map {
                ChapterEntry(
                    chapterID: $0.chapter.chapterID,
                    startPageID: $0.chapter.startPageID,
                    resumePageID: $0.chapter.resumePageID
                )
            }
        }
    }

    enum Action: Equatable {
        case task
        case reloadRequested
        case loadResponse(LoadResponse)
        case startButtonTapped
        case resumeButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case chapterRequested(
            chapterID: ChapterID,
            pageID: LearningPageID
        )
    }

    enum LoadResponse: Equatable {
        case loaded(HomeSnapshot)
        case failed(message: String)
    }

    @Dependency(\.curriculumClient) var curriculumClient
    @Dependency(\.knowledgeCatalogClient) var knowledgeCatalogClient
    @Dependency(\.learningRecordClient) var learningRecordClient
    @Dependency(\.personalKnowledgeClient) var personalKnowledgeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task, .reloadRequested:
                state.isLoading = true
                state.loadErrorMessage = nil
                let chapterID = Chapter02.id
                let placeholder = state.placeholderSnapshot

                return .run { send in
                    do {
                        let chapter = try await curriculumClient.loadChapter(
                            chapterID
                        )
                        let catalog = try await knowledgeCatalogClient.loadCatalog()
                        let progress = try await learningRecordClient.loadProgress(
                            chapter.id
                        )
                        let pageIDs = await MainActor.run {
                            chapter.allPages.map(\.id)
                        }
                        var responses: [ActivityResponse] = []
                        var evidence: [LearningEvidence] = []
                        for pageID in pageIDs {
                            responses += try await learningRecordClient.loadResponses(pageID)
                            evidence += try await learningRecordClient.loadEvidence(pageID)
                        }

                        let conceptIDs = await MainActor.run {
                            let linkedConceptIDs = chapter.allPages.flatMap { page in
                                page.knowledgeLinks.map(\.conceptID)
                                    + page.knowledgeContext.currentlyUsedConceptIDs
                                    + page.knowledgeContext.nearbyKnowledge.map(\.conceptID)
                            }
                            return Set(linkedConceptIDs).sorted {
                                $0.rawValue < $1.rawValue
                            }
                        }
                        var revisions: [PersonalConceptRevision] = []
                        for conceptID in conceptIDs {
                            revisions += try await personalKnowledgeClient.loadRevisions(conceptID)
                        }

                        let loadedResponses = responses
                        let loadedEvidence = evidence
                        let loadedRevisions = revisions
                        let snapshot = await MainActor.run {
                            HomeSnapshotComposer().compose(
                                chapter: chapter,
                                catalog: catalog,
                                progress: progress,
                                responses: loadedResponses,
                                evidence: loadedEvidence,
                                revisions: loadedRevisions,
                                placeholder: placeholder
                            )
                        }
                        await send(.loadResponse(.loaded(snapshot)))
                    } catch {
                        await send(.loadResponse(.failed(
                            message: error.localizedDescription
                        )))
                    }
                }
                .cancellable(id: "HomeFeature.load", cancelInFlight: true)

            case let .loadResponse(.loaded(snapshot)):
                state.isLoading = false
                state.snapshot = snapshot
                state.chapterEntry = ChapterEntry(
                    chapterID: snapshot.chapter.chapterID,
                    startPageID: snapshot.chapter.startPageID,
                    resumePageID: snapshot.chapter.resumePageID
                )
                return .none

            case let .loadResponse(.failed(message)):
                state.isLoading = false
                state.loadErrorMessage = message
                return .none

            case .startButtonTapped:
                guard let entry = state.chapterEntry else { return .none }
                return .send(.delegate(.chapterRequested(
                    chapterID: entry.chapterID,
                    pageID: entry.startPageID
                )))

            case .resumeButtonTapped:
                guard let entry = state.chapterEntry,
                      let resumePageID = entry.resumePageID
                else { return .none }
                return .send(.delegate(.chapterRequested(
                    chapterID: entry.chapterID,
                    pageID: resumePageID
                )))

            case .delegate:
                return .none
            }
        }
    }

}
