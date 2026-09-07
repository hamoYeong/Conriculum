import ComposableArchitecture
import Foundation

@Reducer
struct HomeFeature {
    struct V1ChapterEntry: Equatable, Sendable {
        let chapterID: ChapterID
        let startPageID: LearningPageID
        let resumePageID: LearningPageID?
    }

    @ObservableState
    struct State: Equatable {
        var selectedContentVersion: ContentVersion = .v2
        var v1IsLoading = false
        var v1ChapterEntry: V1ChapterEntry?
        var v1Snapshot: V1HomeSnapshot?
        var v1PlaceholderSnapshot: V1HomeSnapshot?
        var v1LoadErrorMessage: String?
        var manifest: ContentManifest?
        var learningProgress: CourseProgress = .empty
        var selectedStageID = "v2.s1"
        var contentLoadErrorMessage: String?
        var v1PendingPersonalizationReviews: [
            V1KnowledgePersonalizationReview
        ]

        init(
            v1Snapshot: V1HomeSnapshot? = nil,
            usesSnapshotAsPlaceholder: Bool = false,
            v1PendingPersonalizationReviews: [
                V1KnowledgePersonalizationReview
            ] = []
        ) {
            self.v1Snapshot = v1Snapshot
            self.v1PendingPersonalizationReviews = v1PendingPersonalizationReviews
            v1PlaceholderSnapshot = usesSnapshotAsPlaceholder ? v1Snapshot : nil
            v1ChapterEntry = v1Snapshot.map {
                V1ChapterEntry(
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
        case contentReloadRequested
        case v1WorkspaceReturned([V1KnowledgePersonalizationReview])
        case learningReturned
        case v1LoadResponse(V1LoadResponse)
        case contentLoadResponse(ContentLoadResponse)
        case contentVersionSelected(ContentVersion)
        case stageSelected(String)
        case learningChapterSelected(String)
        case v1StartButtonTapped
        case v1ResumeButtonTapped
        case v1ChapterSelected(ChapterID)
        case knowledgeSystemButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case v1ChapterRequested(
            chapterID: ChapterID,
            pageID: LearningPageID
        )
        case knowledgeSystemRequested
        case pageRequested(String)
    }

    enum V1LoadResponse: Equatable {
        case loaded(V1HomeSnapshot)
        case failed(message: String)
    }

    enum ContentLoadResponse: Equatable {
        case loaded(ContentVersion, ContentManifest, CourseProgress)
        case failed(ContentVersion, String)
    }

    @Dependency(\.v1CurriculumClient) var v1CurriculumClient
    @Dependency(\.v1KnowledgeCatalogClient) var v1KnowledgeCatalogClient
    @Dependency(\.v1LearningRecordClient) var v1LearningRecordClient
    @Dependency(\.v1PersonalKnowledgeClient) var v1PersonalKnowledgeClient
    @Dependency(\.contentSettingsClient) var contentSettingsClient
    @Dependency(\.contentClient) var contentClient
    @Dependency(\.progressClient) var progressClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .v1WorkspaceReturned(pendingReviews):
                state.v1PendingPersonalizationReviews = pendingReviews
                return .send(.reloadRequested)

            case .task, .reloadRequested:
                state.v1IsLoading = true
                state.v1LoadErrorMessage = nil
                let placeholder = state.v1PlaceholderSnapshot
                let preferredChapterID = state.v1ChapterEntry?.chapterID
                let pendingReviews = state.v1PendingPersonalizationReviews

                let v1Load: Effect<Action> = .run { send in
                    do {
                        let chapters = try await v1CurriculumClient.loadChapters()
                        var progressByChapter: [ChapterID: V1LearningProgress] = [:]
                        for item in chapters {
                            if let progress = try await v1LearningRecordClient.loadProgress(item.id),
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
                            throw V1ContentClientError.noChaptersAvailable
                        }
                        let catalog = try await v1KnowledgeCatalogClient.loadCatalog()
                        let progress = progressByChapter[chapter.id]
                        let pageIDs = await MainActor.run {
                            chapter.allPages.map(\.id)
                        }
                        var responses: [V1ActivityResponse] = []
                        var evidence: [V1LearningEvidence] = []
                        for pageID in pageIDs {
                            responses += try await v1LearningRecordClient.loadResponses(pageID)
                            evidence += try await v1LearningRecordClient.loadEvidence(pageID)
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
                            async let conceptRevisions = v1PersonalKnowledgeClient
                                .loadRevisions(conceptID)
                            async let conceptRelations = v1PersonalKnowledgeClient
                                .loadRelations(conceptID)
                            revisions += try await conceptRevisions
                            relations += try await conceptRelations
                        }

                        let loadedResponses = responses
                        let loadedEvidence = evidence
                        let loadedRevisions = revisions
                        let loadedRelations = relations
                        let loadedProgress = progressByChapter
                        let v1Snapshot = await MainActor.run {
                            V1HomeSnapshotComposer().compose(
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
                        await send(.v1LoadResponse(.loaded(v1Snapshot)))
                    } catch {
                        await send(.v1LoadResponse(.failed(
                            message: error.localizedDescription
                        )))
                    }
                }
                .cancellable(id: "HomeFeature.load", cancelInFlight: true)

                return v1Load

            case .contentReloadRequested:
                state.contentLoadErrorMessage = nil
                return .run { send in
                    let selectedVersion = await contentSettingsClient.loadSelectedVersion()
                    do {
                        async let manifestRequest = contentClient.loadManifest()
                        async let progressRequest = progressClient.load()
                        await send(.contentLoadResponse(.loaded(
                            selectedVersion,
                            try await manifestRequest,
                            try await progressRequest
                        )))
                    } catch {
                        await send(.contentLoadResponse(.failed(
                            selectedVersion,
                            error.localizedDescription
                        )))
                    }
                }
                .cancellable(id: "HomeFeature.contentLoad", cancelInFlight: true)

            case let .v1LoadResponse(.loaded(v1Snapshot)):
                state.v1IsLoading = false
                state.v1Snapshot = v1Snapshot
                state.v1ChapterEntry = V1ChapterEntry(
                    chapterID: v1Snapshot.chapter.chapterID,
                    startPageID: v1Snapshot.chapter.startPageID,
                    resumePageID: v1Snapshot.chapter.resumePageID
                )
                return .none

            case let .v1LoadResponse(.failed(message)):
                state.v1IsLoading = false
                state.v1LoadErrorMessage = message
                return .none

            case let .contentLoadResponse(.loaded(version, manifest, progress)):
                state.selectedContentVersion = version
                state.manifest = manifest
                state.learningProgress = progress
                state.contentLoadErrorMessage = nil
                let currentChapterID = ChapterStatusResolver(
                    manifest: manifest,
                    progress: progress
                ).currentChapterID
                if let stage = manifest.stages.first(where: { stage in
                    stage.chapters.contains { $0.id == currentChapterID }
                }) {
                    state.selectedStageID = stage.id
                }
                return .none

            case let .contentLoadResponse(.failed(version, message)):
                state.selectedContentVersion = version
                state.contentLoadErrorMessage = message
                return .none

            case let .contentVersionSelected(version):
                state.selectedContentVersion = version
                let reload: Effect<Action> = version == .v2 && state.manifest == nil
                    ? .send(.contentReloadRequested)
                    : .none
                return .merge(
                    .run { _ in await contentSettingsClient.saveSelectedVersion(version) },
                    reload
                )

            case let .stageSelected(stageID):
                guard state.manifest?.stage(id: stageID) != nil else { return .none }
                state.selectedStageID = stageID
                return .none

            case let .learningChapterSelected(chapterID):
                guard let chapter = state.manifest?.chapter(id: chapterID),
                      let firstPageID = chapter.firstPageID
                else { return .none }
                let resumePageID = state.learningProgress.lastVisitedPageID.flatMap { pageID in
                    chapter.pages.contains { $0.id == pageID } ? pageID : nil
                }
                return .send(.delegate(.pageRequested(resumePageID ?? firstPageID)))

            case .learningReturned:
                return .send(.contentReloadRequested)

            case .v1StartButtonTapped:
                guard let entry = state.v1ChapterEntry else { return .none }
                return .send(.delegate(.v1ChapterRequested(
                    chapterID: entry.chapterID,
                    pageID: entry.startPageID
                )))

            case .v1ResumeButtonTapped:
                guard let entry = state.v1ChapterEntry,
                      let resumePageID = entry.resumePageID
                else { return .none }
                return .send(.delegate(.v1ChapterRequested(
                    chapterID: entry.chapterID,
                    pageID: resumePageID
                )))

            case .knowledgeSystemButtonTapped:
                return .send(.delegate(.knowledgeSystemRequested))

            case let .v1ChapterSelected(chapterID):
                guard let chapter = state.v1Snapshot?.availableChapters.first(where: {
                    $0.chapterID == chapterID
                }) else { return .none }
                return .send(.delegate(.v1ChapterRequested(
                    chapterID: chapterID,
                    pageID: chapter.resumePageID ?? chapter.startPageID
                )))

            case .delegate:
                return .none
            }
        }
    }

}
