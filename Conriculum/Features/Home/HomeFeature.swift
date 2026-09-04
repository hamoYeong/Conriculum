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
        var pendingPersonalizationReviews: [
            KnowledgePersonalizationReview
        ]

        init(
            snapshot: HomeSnapshot? = nil,
            usesSnapshotAsPlaceholder: Bool = false,
            pendingPersonalizationReviews: [
                KnowledgePersonalizationReview
            ] = []
        ) {
            self.snapshot = snapshot
            self.pendingPersonalizationReviews = pendingPersonalizationReviews
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
        case workspaceReturned([KnowledgePersonalizationReview])
        case loadResponse(LoadResponse)
        case startButtonTapped
        case resumeButtonTapped
        case chapterSelected(ChapterID)
        case knowledgeSystemButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case chapterRequested(
            chapterID: ChapterID,
            pageID: LearningPageID
        )
        case knowledgeSystemRequested
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
            case let .workspaceReturned(pendingReviews):
                state.pendingPersonalizationReviews = pendingReviews
                return .send(.reloadRequested)

            case .task, .reloadRequested:
                state.isLoading = true
                state.loadErrorMessage = nil
                let placeholder = state.placeholderSnapshot
                let preferredChapterID = state.chapterEntry?.chapterID
                let pendingReviews = state.pendingPersonalizationReviews

                return .run { send in
                    do {
                        let chapters = try await curriculumClient.loadChapters()
                        var progressByChapter: [ChapterID: LearningProgress] = [:]
                        for item in chapters {
                            if let progress = try await learningRecordClient.loadProgress(item.id),
                               await MainActor.run(body: { item.page(id: progress.currentPageID) != nil }) {
                                progressByChapter[item.id] = progress
                            }
                        }
                        let mostRecent = progressByChapter.values.max {
                            ($0.updatedAt, $0.chapterID.rawValue) < ($1.updatedAt, $1.chapterID.rawValue)
                        }?.chapterID
                        guard let chapter = chapters.first(where: {
                            $0.id == (mostRecent ?? preferredChapterID)
                        }) ?? chapters.first else {
                            throw ContentClientError.noChaptersAvailable
                        }
                        let catalog = try await knowledgeCatalogClient.loadCatalog()
                        let progress = progressByChapter[chapter.id]
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
                        var relations: [PersonalKnowledgeRelation] = []
                        for conceptID in conceptIDs {
                            async let conceptRevisions = personalKnowledgeClient
                                .loadRevisions(conceptID)
                            async let conceptRelations = personalKnowledgeClient
                                .loadRelations(conceptID)
                            revisions += try await conceptRevisions
                            relations += try await conceptRelations
                        }

                        let loadedResponses = responses
                        let loadedEvidence = evidence
                        let loadedRevisions = revisions
                        let loadedRelations = relations
                        let loadedProgress = progressByChapter
                        let snapshot = await MainActor.run {
                            HomeSnapshotComposer().compose(
                                chapter: chapter,
                                catalog: catalog,
                                progress: progress,
                                responses: loadedResponses,
                                evidence: loadedEvidence,
                                revisions: loadedRevisions,
                                relations: loadedRelations,
                                pendingPersonalizationReviews: pendingReviews,
                                placeholder: placeholder,
                                availableChapters: chapters,
                                progressByChapter: loadedProgress
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

            case .knowledgeSystemButtonTapped:
                return .send(.delegate(.knowledgeSystemRequested))

            case let .chapterSelected(chapterID):
                guard let chapter = state.snapshot?.availableChapters.first(where: {
                    $0.chapterID == chapterID
                }) else { return .none }
                return .send(.delegate(.chapterRequested(
                    chapterID: chapterID,
                    pageID: chapter.resumePageID ?? chapter.startPageID
                )))

            case .delegate:
                return .none
            }
        }
    }

}
