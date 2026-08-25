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
        var knowledgeCatalog: KnowledgeCatalog?
        var component = LearningComponentFeature.State()
        var completedPageIDs: Set<LearningPageID> = []
        var activityDrafts: [LearningActivityID: ActivityDraft] = [:]
        var activitySaveStates: [
            LearningActivityID: ActivityDraftSaveState
        ] = [:]
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
        case activityAutosaveDelayElapsed(LearningActivityID)
        case activitySaveResponse(
            activityID: LearningActivityID,
            response: ActivitySaveResponse
        )
        case activityRetryButtonTapped(LearningActivityID)
        case component(LearningComponentFeature.Action)
        case startButtonTapped
        case previousButtonTapped
        case nextButtonTapped
        case navigationResponse(NavigationResponse)
        case delegate(Delegate)
    }

    enum LoadResponse: Equatable, Sendable {
        case loaded(
            chapter: Chapter,
            knowledgeCatalog: KnowledgeCatalog,
            progress: LearningProgress?
        )
        case failed(message: String)
    }

    enum NavigationResponse: Equatable, Sendable {
        case saved(
            destination: NavigationDestination,
            progress: LearningProgress,
            drafts: [ActivityDraft]
        )
        case failed(
            drafts: [ActivityDraft],
            savedActivityIDs: [LearningActivityID],
            savedAt: Date,
            message: String
        )
    }

    enum ActivitySaveResponse: Equatable, Sendable {
        case saved(draft: ActivityDraft, savedAt: Date)
        case failed(draft: ActivityDraft, message: String)
    }

    enum Delegate: Equatable {
        case currentPageChanged(LearningPageID)
        case personalKnowledge(PersonalKnowledgeComponentAction)
    }

    @Dependency(\.curriculumClient) var curriculumClient
    @Dependency(\.knowledgeCatalogClient) var knowledgeCatalogClient
    @Dependency(\.learningRecordClient) var learningRecordClient
    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Scope(state: \.component, action: \.component) {
            LearningComponentFeature()
        }

        Reduce { state, action in
            switch action {
            case .task:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.loadErrorMessage = nil
                let chapterID = state.chapterID

                return .run { send in
                    do {
                        async let chapter = curriculumClient.loadChapter(
                            chapterID
                        )
                        async let knowledgeCatalog = knowledgeCatalogClient
                            .loadCatalog()
                        async let progress = learningRecordClient.loadProgress(
                            chapterID
                        )
                        await send(.loadResponse(.loaded(
                            chapter: try await chapter,
                            knowledgeCatalog: try await knowledgeCatalog,
                            progress: try await progress
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

            case let .loadResponse(.loaded(
                chapter,
                knowledgeCatalog,
                progress
            )):
                let requestedPageID = state.currentPageID
                let resolvedPageID = Self.resolvedPageID(
                    requestedPageID: requestedPageID,
                    savedProgress: progress,
                    chapter: chapter
                )

                state.isLoading = false
                state.chapter = chapter
                state.knowledgeCatalog = knowledgeCatalog
                state.component = LearningComponentFeature.State()
                state.currentPageID = resolvedPageID
                state.completedPageIDs = Set(
                    progress?.completedPageIDs.filter {
                        chapter.progressPageIDs.contains($0)
                    } ?? []
                )
                state.activityDrafts = [:]
                state.activitySaveStates = [:]
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

                let responseID = state.activityDrafts[activityID]?.responseID
                    ?? ActivityResponseID(
                        rawValue: uuid().uuidString.lowercased()
                    )
                state.activityDrafts[activityID] = ActivityDraft(
                    responseID: responseID,
                    activityID: activityID,
                    fields: fields
                )
                state.activitySaveStates[activityID] = .pending
                state.navigationErrorMessage = nil
                let cancelID = Self.autosaveCancelID(for: activityID)
                return .run { send in
                    try await clock.sleep(for: .milliseconds(750))
                    await send(.activityAutosaveDelayElapsed(activityID))
                }
                .cancellable(id: cancelID, cancelInFlight: true)

            case let .activityAutosaveDelayElapsed(activityID):
                return saveActivityDraft(
                    state: &state,
                    activityID: activityID
                )

            case let .activitySaveResponse(activityID, .saved(draft, savedAt)):
                guard state.activityDrafts[activityID] == draft else {
                    return .none
                }
                state.activitySaveStates[activityID] = .saved(savedAt)
                return .none

            case let .activitySaveResponse(activityID, .failed(draft, message)):
                guard state.activityDrafts[activityID] == draft else {
                    return .none
                }
                state.activitySaveStates[activityID] = .persistenceError(message)
                return .none

            case let .activityRetryButtonTapped(activityID):
                state.navigationErrorMessage = nil
                return saveActivityDraft(
                    state: &state,
                    activityID: activityID
                )

            case let .component(.delegate(.activityFieldsChanged(
                activityID,
                fields
            ))):
                return .send(.activityDraftChanged(
                    activityID: activityID,
                    fields: fields
                ))

            case let .component(.delegate(.personalKnowledge(action))):
                return .send(.delegate(.personalKnowledge(action)))

            case .component:
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

            case let .navigationResponse(.saved(destination, progress, drafts)):
                state.isSavingNavigation = false
                guard drafts.allSatisfy({
                    state.activityDrafts[$0.activityID] == $0
                }) else {
                    state.navigationErrorMessage =
                        "저장 중 입력이 변경되었습니다. 다시 이동해 주세요."
                    return .none
                }
                state.navigationErrorMessage = nil
                state.completedPageIDs = progress.completedPageIDs
                state.activityDrafts = [:]
                state.activitySaveStates = [:]
                state.component = LearningComponentFeature.State()

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

            case let .navigationResponse(.failed(
                drafts,
                savedActivityIDs,
                savedAt,
                message
            )):
                state.isSavingNavigation = false
                state.navigationErrorMessage = message
                let savedIDs = Set(savedActivityIDs)
                for draft in drafts where
                    state.activityDrafts[draft.activityID] == draft
                {
                    if savedIDs.contains(draft.activityID) {
                        state.activitySaveStates[draft.activityID] = .saved(savedAt)
                    } else if case .some(.saved) = state.activitySaveStates[
                        draft.activityID
                    ] {
                        continue
                    } else {
                        state.activitySaveStates[draft.activityID] =
                            .persistenceError(message)
                    }
                }
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

        let drafts = state.activityDrafts.values.sorted {
            $0.activityID.rawValue < $1.activityID.rawValue
        }
        var hasValidationError = false
        for draft in drafts {
            if let message = Self.validationMessage(for: draft) {
                state.activitySaveStates[draft.activityID] =
                    .validationError(message)
                hasValidationError = true
            }
        }
        guard !hasValidationError else {
            state.navigationErrorMessage =
                "저장할 입력을 확인한 뒤 다시 이동해 주세요."
            return .none
        }

        let draftsToSave = drafts.filter { draft in
            if case .some(.saved) = state.activitySaveStates[draft.activityID] {
                return false
            }
            return true
        }
        for draft in draftsToSave {
            state.activitySaveStates[draft.activityID] = .saving
        }

        let timestamp = now
        let currentPageID = state.currentPageID
        let progress = LearningProgress(
            chapterID: state.chapterID,
            currentPageID: targetPageID,
            completedPageIDs: state.completedPageIDs,
            updatedAt: timestamp
        )

        state.isSavingNavigation = true
        state.navigationErrorMessage = nil

        let saveEffect = Effect<Action>.run { send in
            var savedActivityIDs: [LearningActivityID] = []
            do {
                for draft in draftsToSave {
                    let response = ActivityResponse(
                        id: draft.responseID,
                        activityID: draft.activityID,
                        pageID: currentPageID,
                        fields: draft.fields,
                        recordedAt: timestamp
                    )
                    try await learningRecordClient.saveResponse(response)
                    savedActivityIDs.append(draft.activityID)
                }
                try await learningRecordClient.saveProgress(progress)
                await send(.navigationResponse(.saved(
                    destination: destination,
                    progress: progress,
                    drafts: drafts
                )))
            } catch {
                await send(.navigationResponse(.failed(
                    drafts: drafts,
                    savedActivityIDs: savedActivityIDs,
                    savedAt: timestamp,
                    message: error.localizedDescription
                )))
            }
        }

        let cancellationEffects: [Effect<Action>] = drafts.map {
            .cancel(id: Self.autosaveCancelID(for: $0.activityID))
        }
        return .merge(cancellationEffects + [saveEffect])
    }

    private func saveActivityDraft(
        state: inout State,
        activityID: LearningActivityID
    ) -> Effect<Action> {
        guard let draft = state.activityDrafts[activityID] else {
            return .none
        }
        if let message = Self.validationMessage(for: draft) {
            state.activitySaveStates[activityID] = .validationError(message)
            return .none
        }

        let savedAt = now
        let pageID = state.currentPageID
        let response = ActivityResponse(
            id: draft.responseID,
            activityID: draft.activityID,
            pageID: pageID,
            fields: draft.fields,
            recordedAt: savedAt
        )
        state.activitySaveStates[activityID] = .saving

        return .run { send in
            do {
                try await learningRecordClient.saveResponse(response)
                await send(.activitySaveResponse(
                    activityID: activityID,
                    response: .saved(draft: draft, savedAt: savedAt)
                ))
            } catch {
                await send(.activitySaveResponse(
                    activityID: activityID,
                    response: .failed(
                        draft: draft,
                        message: error.localizedDescription
                    )
                ))
            }
        }
    }

    private static func validationMessage(
        for draft: ActivityDraft
    ) -> String? {
        guard !draft.fields.isEmpty else {
            return "저장할 입력이 없습니다."
        }
        let keys = draft.fields.map { $0.key.trimmingCharacters(in: .whitespaces) }
        guard keys.allSatisfy({ !$0.isEmpty }) else {
            return "입력 항목을 식별할 수 없습니다."
        }
        guard Set(keys).count == keys.count else {
            return "같은 입력 항목이 두 번 포함되어 있습니다."
        }
        return nil
    }

    private static func autosaveCancelID(
        for activityID: LearningActivityID
    ) -> String {
        "ChapterLearningFeature.autosave.\(activityID.rawValue)"
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
