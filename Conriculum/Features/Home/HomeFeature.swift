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
        var selectedContentVersion: ContentVersion = .v1
        var isLoading = false
        var chapterEntry: ChapterEntry?
        var snapshot: HomeSnapshot?
        var placeholderSnapshot: HomeSnapshot?
        var loadErrorMessage: String?
        var v2Manifest: V2ContentManifest?
        var v2Progress: V2Progress = .empty
        var selectedV2StageID = "v2.s1"
        var v2LoadErrorMessage: String?
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
        case v2ReloadRequested
        case workspaceReturned([KnowledgePersonalizationReview])
        case v2WorkspaceReturned
        case loadResponse(LoadResponse)
        case v2LoadResponse(V2LoadResponse)
        case contentVersionSelected(ContentVersion)
        case v2StageSelected(String)
        case v2ChapterSelected(String)
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
        case v2PageRequested(String)
    }

    enum LoadResponse: Equatable {
        case loaded(HomeSnapshot)
        case failed(message: String)
    }

    enum V2LoadResponse: Equatable {
        case loaded(ContentVersion, V2ContentManifest, V2Progress)
        case failed(ContentVersion, String)
    }

    @Dependency(\.curriculumClient) var curriculumClient
    @Dependency(\.knowledgeCatalogClient) var knowledgeCatalogClient
    @Dependency(\.learningRecordClient) var learningRecordClient
    @Dependency(\.personalKnowledgeClient) var personalKnowledgeClient
    @Dependency(\.contentSettingsClient) var contentSettingsClient
    @Dependency(\.v2ContentClient) var v2ContentClient
    @Dependency(\.v2ProgressClient) var v2ProgressClient

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

                let v1Load: Effect<Action> = .run { send in
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

                return v1Load

            case .v2ReloadRequested:
                state.v2LoadErrorMessage = nil
                return .run { send in
                    let selectedVersion = await contentSettingsClient.loadSelectedVersion()
                    do {
                        async let manifestRequest = v2ContentClient.loadManifest()
                        async let progressRequest = v2ProgressClient.load()
                        await send(.v2LoadResponse(.loaded(
                            selectedVersion,
                            try await manifestRequest,
                            try await progressRequest
                        )))
                    } catch {
                        await send(.v2LoadResponse(.failed(
                            selectedVersion,
                            error.localizedDescription
                        )))
                    }
                }
                .cancellable(id: "HomeFeature.v2Load", cancelInFlight: true)

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

            case let .v2LoadResponse(.loaded(version, manifest, progress)):
                state.selectedContentVersion = version
                state.v2Manifest = manifest
                state.v2Progress = progress
                state.v2LoadErrorMessage = nil
                let currentChapterID = V2ChapterStatusResolver(
                    manifest: manifest,
                    progress: progress
                ).currentChapterID
                if let stage = manifest.stages.first(where: { stage in
                    stage.chapters.contains { $0.id == currentChapterID }
                }) {
                    state.selectedV2StageID = stage.id
                }
                return .none

            case let .v2LoadResponse(.failed(version, message)):
                state.selectedContentVersion = version
                state.v2LoadErrorMessage = message
                return .none

            case let .contentVersionSelected(version):
                state.selectedContentVersion = version
                let reload: Effect<Action> = version == .v2 && state.v2Manifest == nil
                    ? .send(.v2ReloadRequested)
                    : .none
                return .merge(
                    .run { _ in await contentSettingsClient.saveSelectedVersion(version) },
                    reload
                )

            case let .v2StageSelected(stageID):
                guard state.v2Manifest?.stage(id: stageID) != nil else { return .none }
                state.selectedV2StageID = stageID
                return .none

            case let .v2ChapterSelected(chapterID):
                guard let chapter = state.v2Manifest?.chapter(id: chapterID),
                      let firstPageID = chapter.firstPageID
                else { return .none }
                let resumePageID = state.v2Progress.lastVisitedPageID.flatMap { pageID in
                    chapter.pages.contains { $0.id == pageID } ? pageID : nil
                }
                return .send(.delegate(.v2PageRequested(resumePageID ?? firstPageID)))

            case .v2WorkspaceReturned:
                return .send(.v2ReloadRequested)

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
