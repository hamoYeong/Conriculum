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
        var loadErrorMessage: String?
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
        case loaded(ChapterEntry)
        case failed(message: String)
    }

    @Dependency(\.curriculumClient) var curriculumClient
    @Dependency(\.learningRecordClient) var learningRecordClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task, .reloadRequested:
                state.isLoading = true
                state.loadErrorMessage = nil
                let chapterID = Chapter02.id

                return .run { send in
                    do {
                        let chapter = try await curriculumClient.loadChapter(
                            chapterID
                        )
                        let progress = try await learningRecordClient.loadProgress(
                            chapter.id
                        )
                        let entry = await MainActor.run {
                            let resumePageID = progress.flatMap { progress in
                                chapter.page(id: progress.currentPageID) == nil
                                    ? nil
                                    : progress.currentPageID
                            }
                            return ChapterEntry(
                                chapterID: chapter.id,
                                startPageID: chapter.overview.id,
                                resumePageID: resumePageID
                            )
                        }
                        await send(.loadResponse(.loaded(entry)))
                    } catch {
                        await send(.loadResponse(.failed(
                            message: error.localizedDescription
                        )))
                    }
                }
                .cancellable(id: "HomeFeature.load", cancelInFlight: true)

            case let .loadResponse(.loaded(entry)):
                state.isLoading = false
                state.chapterEntry = entry
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
