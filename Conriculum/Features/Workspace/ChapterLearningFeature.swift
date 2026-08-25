import ComposableArchitecture
import Foundation

@Reducer
struct ChapterLearningFeature {
    struct ActivityDraft: Equatable, Sendable {
        let responseID: ActivityResponseID
        let activityID: LearningActivityID
        var fields: [ActivityResponseField]
    }

    enum NavigationDestination: Equatable, Sendable {
        case page(LearningPageID)
        case completionSummary
    }

    @ObservableState
    struct State: Equatable {
        let chapterID: ChapterID
        var currentPageID: LearningPageID
        var chapter: Chapter?
        var completedPageIDs: Set<LearningPageID> = []
        var currentDraft: ActivityDraft?
        var isLoading = false
        var isSavingNavigation = false
        var isShowingCompletionSummary = false
        var loadErrorMessage: String?
        var navigationErrorMessage: String?

        init(
            chapterID: ChapterID,
            currentPageID: LearningPageID
        ) {
            self.chapterID = chapterID
            self.currentPageID = currentPageID
        }

        var currentPage: LearningPage? {
            chapter?.page(id: currentPageID)
        }

        var canNavigatePrevious: Bool {
            guard let chapter,
                  let index = chapter.progressPageIDs.firstIndex(of: currentPageID)
            else { return false }
            return index > chapter.progressPageIDs.startIndex
        }

        var isLastPage: Bool {
            chapter?.progressPageIDs.last == currentPageID
        }

        var progressPosition: Int? {
            guard let chapter,
                  let index = chapter.progressPageIDs.firstIndex(of: currentPageID)
            else { return nil }
            return chapter.progressPageIDs.distance(
                from: chapter.progressPageIDs.startIndex,
                to: index
            ) + 1
        }
    }

    enum Action: Equatable {
        case task
        case loadResponse(LoadResponse)
        case activityDraftChanged(
            activityID: LearningActivityID,
            fields: [ActivityResponseField]
        )
        case startButtonTapped
        case previousButtonTapped
        case nextButtonTapped
        case navigationResponse(NavigationResponse)
        case delegate(Delegate)
    }

    enum LoadResponse: Equatable, Sendable {
        case loaded(chapter: Chapter, progress: LearningProgress?)
        case failed(message: String)
    }

    enum NavigationResponse: Equatable, Sendable {
        case saved(
            destination: NavigationDestination,
            progress: LearningProgress,
            draft: ActivityDraft?
        )
        case failed(message: String)
    }

    enum Delegate: Equatable {
        case currentPageChanged(LearningPageID)
    }

    @Dependency(\.curriculumClient) var curriculumClient
    @Dependency(\.learningRecordClient) var learningRecordClient
    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.loadErrorMessage = nil
                let chapterID = state.chapterID

                return .run { send in
                    do {
                        let chapter = try await curriculumClient.loadChapter(chapterID)
                        let progress = try await learningRecordClient.loadProgress(chapterID)
                        await send(.loadResponse(.loaded(
                            chapter: chapter,
                            progress: progress
                        )))
                    } catch {
                        await send(.loadResponse(.failed(
                            message: error.localizedDescription
                        )))
                    }
                }
                .cancellable(
                    id: "ChapterLearningFeature.load",
                    cancelInFlight: true
                )

            case let .loadResponse(.loaded(chapter, progress)):
                let requestedPageID = state.currentPageID
                let resolvedPageID = Self.resolvedPageID(
                    requestedPageID: requestedPageID,
                    savedProgress: progress,
                    chapter: chapter
                )

                state.isLoading = false
                state.chapter = chapter
                state.currentPageID = resolvedPageID
                state.completedPageIDs = Set(
                    progress?.completedPageIDs.filter {
                        chapter.progressPageIDs.contains($0)
                    } ?? []
                )
                state.currentDraft = nil
                state.isShowingCompletionSummary = false
                state.loadErrorMessage = nil
                state.navigationErrorMessage = nil

                guard requestedPageID != resolvedPageID else { return .none }
                return .send(.delegate(.currentPageChanged(resolvedPageID)))

            case let .loadResponse(.failed(message)):
                state.isLoading = false
                state.loadErrorMessage = message
                return .none

            case let .activityDraftChanged(activityID, fields):
                guard state.currentPage?.activities.contains(where: {
                    $0.id == activityID
                }) == true else { return .none }

                let responseID = state.currentDraft?.activityID == activityID
                    ? state.currentDraft?.responseID
                    : ActivityResponseID(
                        rawValue: uuid().uuidString.lowercased()
                    )
                guard let responseID else { return .none }
                state.currentDraft = ActivityDraft(
                    responseID: responseID,
                    activityID: activityID,
                    fields: fields
                )
                state.navigationErrorMessage = nil
                return .none

            case .startButtonTapped:
                guard state.currentPage?.kind == .overview,
                      let firstPageID = state.chapter?.progressPageIDs.first
                else { return .none }
                return saveAndNavigate(
                    state: &state,
                    to: .page(firstPageID)
                )

            case .previousButtonTapped:
                guard let chapter = state.chapter,
                      let index = chapter.progressPageIDs.firstIndex(
                        of: state.currentPageID
                      ),
                      index > chapter.progressPageIDs.startIndex
                else { return .none }
                let previousIndex = chapter.progressPageIDs.index(before: index)
                return saveAndNavigate(
                    state: &state,
                    to: .page(chapter.progressPageIDs[previousIndex])
                )

            case .nextButtonTapped:
                guard let chapter = state.chapter,
                      let index = chapter.progressPageIDs.firstIndex(
                        of: state.currentPageID
                      )
                else { return .none }

                let nextIndex = chapter.progressPageIDs.index(after: index)
                if nextIndex == chapter.progressPageIDs.endIndex {
                    return saveAndNavigate(
                        state: &state,
                        to: .completionSummary
                    )
                }
                return saveAndNavigate(
                    state: &state,
                    to: .page(chapter.progressPageIDs[nextIndex])
                )

            case let .navigationResponse(.saved(destination, progress, draft)):
                state.isSavingNavigation = false
                state.navigationErrorMessage = nil
                state.completedPageIDs = progress.completedPageIDs
                if state.currentDraft == draft {
                    state.currentDraft = nil
                }

                switch destination {
                case let .page(pageID):
                    guard state.currentPageID != pageID else { return .none }
                    state.currentPageID = pageID
                    state.isShowingCompletionSummary = false
                    return .send(.delegate(.currentPageChanged(pageID)))

                case .completionSummary:
                    state.isShowingCompletionSummary = true
                    return .none
                }

            case let .navigationResponse(.failed(message)):
                state.isSavingNavigation = false
                state.navigationErrorMessage = message
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func saveAndNavigate(
        state: inout State,
        to destination: NavigationDestination
    ) -> Effect<Action> {
        guard !state.isSavingNavigation else { return .none }

        let targetPageID: LearningPageID
        switch destination {
        case let .page(pageID):
            guard state.chapter?.page(id: pageID) != nil else { return .none }
            targetPageID = pageID
        case .completionSummary:
            targetPageID = state.currentPageID
        }

        let timestamp = now
        let draft = state.currentDraft
        let response = draft.map {
            ActivityResponse(
                id: $0.responseID,
                activityID: $0.activityID,
                pageID: state.currentPageID,
                fields: $0.fields,
                recordedAt: timestamp
            )
        }
        let progress = LearningProgress(
            chapterID: state.chapterID,
            currentPageID: targetPageID,
            completedPageIDs: state.completedPageIDs,
            updatedAt: timestamp
        )

        state.isSavingNavigation = true
        state.navigationErrorMessage = nil

        return .run { send in
            do {
                if let response {
                    try await learningRecordClient.saveResponse(response)
                }
                try await learningRecordClient.saveProgress(progress)
                await send(.navigationResponse(.saved(
                    destination: destination,
                    progress: progress,
                    draft: draft
                )))
            } catch {
                await send(.navigationResponse(.failed(
                    message: error.localizedDescription
                )))
            }
        }
    }

    private static func resolvedPageID(
        requestedPageID: LearningPageID,
        savedProgress: LearningProgress?,
        chapter: Chapter
    ) -> LearningPageID {
        if let savedProgress {
            return chapter.page(id: savedProgress.currentPageID) == nil
                ? chapter.overview.id
                : savedProgress.currentPageID
        }
        return chapter.page(id: requestedPageID) == nil
            ? chapter.overview.id
            : requestedPageID
    }
}
