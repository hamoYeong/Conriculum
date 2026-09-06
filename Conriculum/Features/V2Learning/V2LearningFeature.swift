import ComposableArchitecture
import Foundation

@Reducer
struct V2LearningFeature {
    @ObservableState
    struct State: Equatable {
        var requestedPageID: String
        var manifest: V2ContentManifest?
        var page: V2LearningPage?
        var progress: V2Progress = .empty
        var isLoading = false
        var isSaving = false
        var loadErrorMessage: String?
        var saveErrorMessage: String?

        init(pageID: String) {
            requestedPageID = pageID
        }

        var stage: V2Stage? {
            page.flatMap { manifest?.stage(id: $0.stageID) }
        }

        var chapter: V2Chapter? {
            page.flatMap { manifest?.chapter(id: $0.chapterID) }
        }

        var orderedPages: [V2PageReference] {
            manifest?.stages.sorted(by: { $0.order < $1.order }).flatMap { stage in
                stage.chapters.sorted(by: { $0.order < $1.order }).flatMap { chapter in
                    chapter.pages.sorted(by: { $0.order < $1.order })
                }
            } ?? []
        }

        var position: Int? {
            guard let page else { return nil }
            return orderedPages.firstIndex { $0.id == page.id }.map { $0 + 1 }
        }

        var canGoPrevious: Bool { (position ?? 1) > 1 }
        var isLastPage: Bool { position == orderedPages.count }
    }

    enum Action: Equatable {
        case task
        case loadResponse(LoadResponse)
        case previousButtonTapped
        case nextButtonTapped
        case navigationResponse(NavigationResponse)
        case homeButtonTapped
        case delegate(Delegate)
    }

    enum LoadResponse: Equatable {
        case loaded(V2ContentManifest, V2LearningPage, V2Progress)
        case failed(String)
    }

    enum NavigationResponse: Equatable {
        case loaded(V2LearningPage, V2Progress)
        case savedCompletion(V2Progress)
        case failed(String)
    }

    enum Delegate: Equatable {
        case homeRequested
    }

    @Dependency(\.v2ContentClient) var contentClient
    @Dependency(\.v2ProgressClient) var progressClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.loadErrorMessage = nil
                let requestedPageID = state.requestedPageID
                return .run { send in
                    do {
                        let manifest = try await contentClient.loadManifest()
                        var progress = try await progressClient.load()
                        let savedProgress = progress
                        let resolvedPageID = await MainActor.run {
                            let validRequested = manifest.pageReference(id: requestedPageID)?.id
                            let validResume = savedProgress.lastVisitedPageID.flatMap {
                                manifest.pageReference(id: $0)?.id
                            }
                            return validRequested ?? validResume
                                ?? manifest.stages.first?.chapters.first?.firstPageID
                        }
                        guard let pageID = resolvedPageID else {
                            throw V2ContentError.pageNotFound(requestedPageID)
                        }
                        let page = try await contentClient.loadPage(.init(
                            version: .v2,
                            rawValue: pageID
                        ))
                        progress.lastVisitedPageID = pageID
                        try await progressClient.save(progress)
                        await send(.loadResponse(.loaded(manifest, page, progress)))
                    } catch {
                        await send(.loadResponse(.failed(error.localizedDescription)))
                    }
                }

            case let .loadResponse(.loaded(manifest, page, progress)):
                state.isLoading = false
                state.manifest = manifest
                state.page = page
                state.progress = progress
                state.loadErrorMessage = nil
                return .none

            case let .loadResponse(.failed(message)):
                state.isLoading = false
                state.loadErrorMessage = message
                return .none

            case .previousButtonTapped:
                guard let index = currentIndex(state), index > 0 else { return .none }
                return navigate(state: &state, to: state.orderedPages[index - 1], completingCurrent: false)

            case .nextButtonTapped:
                guard let index = currentIndex(state), let page = state.page else { return .none }
                state.progress.completedPageIDs.insert(page.id)
                if index == state.orderedPages.index(before: state.orderedPages.endIndex) {
                    state.isSaving = true
                    let progress = state.progress
                    return .run { send in
                        do {
                            try await progressClient.save(progress)
                            await send(.navigationResponse(.savedCompletion(progress)))
                        } catch {
                            await send(.navigationResponse(.failed(error.localizedDescription)))
                        }
                    }
                }
                return navigate(state: &state, to: state.orderedPages[index + 1], completingCurrent: true)

            case let .navigationResponse(.loaded(page, progress)):
                state.isSaving = false
                state.page = page
                state.requestedPageID = page.id
                state.progress = progress
                state.saveErrorMessage = nil
                return .none

            case let .navigationResponse(.savedCompletion(progress)):
                state.isSaving = false
                state.progress = progress
                state.saveErrorMessage = nil
                return .none

            case let .navigationResponse(.failed(message)):
                state.isSaving = false
                state.saveErrorMessage = message
                return .none

            case .homeButtonTapped:
                return .send(.delegate(.homeRequested))

            case .delegate:
                return .none
            }
        }
    }

    private func currentIndex(_ state: State) -> Int? {
        guard let page = state.page else { return nil }
        return state.orderedPages.firstIndex { $0.id == page.id }
    }

    private func navigate(
        state: inout State,
        to reference: V2PageReference,
        completingCurrent: Bool
    ) -> Effect<Action> {
        state.isSaving = true
        state.saveErrorMessage = nil
        var progress = state.progress
        if completingCurrent, let page = state.page {
            progress.completedPageIDs.insert(page.id)
        }
        progress.lastVisitedPageID = reference.id
        let navigationProgress = progress
        return .run { send in
            do {
                try await progressClient.save(navigationProgress)
                let page = try await contentClient.loadPage(.init(
                    version: .v2,
                    rawValue: reference.id
                ))
                await send(.navigationResponse(.loaded(page, navigationProgress)))
            } catch {
                await send(.navigationResponse(.failed(error.localizedDescription)))
            }
        }
    }
}
