import ComposableArchitecture
import Foundation

@Reducer
struct HomeFeature {
    @ObservableState
    struct State: Equatable {
        var manifest: ContentManifest?
        var learningProgress: CourseProgress = .empty
        var selectedStageID = "s1"
        var contentLoadErrorMessage: String?
    }

    enum Action: Equatable {
        case task
        case reloadRequested
        case learningReturned
        case contentLoadResponse(ContentLoadResponse)
        case stageSelected(String)
        case learningChapterSelected(String)
        case knowledgeSystemButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case knowledgeSystemRequested
        case pageRequested(String)
    }

    enum ContentLoadResponse: Equatable {
        case loaded(ContentManifest, CourseProgress)
        case failed(String)
    }

    @Dependency(\.contentClient) var contentClient
    @Dependency(\.progressClient) var progressClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task, .reloadRequested:
                state.contentLoadErrorMessage = nil
                return .run { send in
                    do {
                        async let manifestRequest = contentClient.loadManifest()
                        async let progressRequest = progressClient.load()
                        await send(.contentLoadResponse(.loaded(
                            try await manifestRequest,
                            try await progressRequest
                        )))
                    } catch {
                        await send(.contentLoadResponse(.failed(
                            error.localizedDescription
                        )))
                    }
                }
                .cancellable(id: "HomeFeature.contentLoad", cancelInFlight: true)

            case let .contentLoadResponse(.loaded(manifest, progress)):
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

            case let .contentLoadResponse(.failed(message)):
                state.contentLoadErrorMessage = message
                return .none

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
                return .send(.reloadRequested)

            case .knowledgeSystemButtonTapped:
                return .send(.delegate(.knowledgeSystemRequested))

            case .delegate:
                return .none
            }
        }
    }
}
