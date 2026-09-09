import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct LearningWorkspaceTests {
    @Test
    func singleChoiceStoresAttemptsAndShowsImmediateJudgment() async throws {
        let page = try BundledContentStore().loadPage(id: .init(
            version: .v2,
            rawValue: "v2.s1.c1.p1"
        ))
        let activity = try #require(page.blocks.flatMap(\.activities).first)
        let wrongOption = try #require(activity.options.first(where: {
            !activity.correctOptionIDs.contains($0.id)
        }))
        let correctOptionID = try #require(activity.correctOptionIDs.first)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        var state = LearningFeature.State(pageID: page.id)
        state.page = page
        let store = TestStore(initialState: state) {
            LearningFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.progressClient.save = { _ in }
        }

        await store.send(.gameOptionTapped(
            activityID: activity.id,
            optionID: wrongOption.id
        )) {
            $0.isSaving = true
            $0.progress.activityResponses[activity.id] = GameResponse(
                activityID: activity.id,
                selectedOptionIDs: [wrongOption.id],
                isCorrect: false,
                attempts: 1,
                answeredAt: timestamp
            )
        }
        await store.receive(.gameResponseSaveFinished(nil)) {
            $0.isSaving = false
        }

        await store.send(.gameOptionTapped(
            activityID: activity.id,
            optionID: correctOptionID
        )) {
            $0.isSaving = true
            $0.progress.activityResponses[activity.id] = GameResponse(
                activityID: activity.id,
                selectedOptionIDs: [correctOptionID],
                isCorrect: true,
                attempts: 2,
                answeredAt: timestamp
            )
        }
        await store.receive(.gameResponseSaveFinished(nil)) {
            $0.isSaving = false
        }
    }

    @Test
    func multipleChoiceWaitsForSubmitBeforeShowingFeedback() async throws {
        let page = try BundledContentStore().loadPage(id: .init(
            version: .v2,
            rawValue: "v2.s1.c1.p1"
        ))
        let activity = try #require(page.blocks.flatMap(\.activities).first {
            $0.kind == .multipleChoice
        })
        let optionIDs = activity.correctOptionIDs
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        var state = LearningFeature.State(pageID: page.id)
        state.page = page
        let store = TestStore(initialState: state) { LearningFeature() } withDependencies: {
            $0.date.now = timestamp
            $0.progressClient.save = { _ in }
        }

        for optionID in optionIDs.sorted() {
            await store.send(.gameOptionTapped(activityID: activity.id, optionID: optionID)) {
                $0.gameDrafts[activity.id, default: GameDraft()].selectedOptionIDs.insert(optionID)
            }
        }
        #expect(store.state.progress.activityResponses[activity.id] == nil)

        await store.send(.gameSubmitTapped(activityID: activity.id)) {
            $0.gameDrafts.removeValue(forKey: activity.id)
            $0.isSaving = true
            $0.progress.activityResponses[activity.id] = GameResponse(
                activityID: activity.id,
                selectedOptionIDs: optionIDs,
                isCorrect: true,
                attempts: 1,
                answeredAt: timestamp
            )
        }
        await store.receive(.gameResponseSaveFinished(nil)) {
            $0.isSaving = false
        }
    }

    @Test
    func matchingShowsFeedbackOnlyAfterEveryPairIsConnected() async throws {
        let page = try BundledContentStore().loadPage(id: .init(
            version: .v2,
            rawValue: "v2.s1.c1.p1"
        ))
        let activity = try #require(page.blocks.flatMap(\.activities).first {
            $0.kind == .matching
        })
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        var state = LearningFeature.State(pageID: page.id)
        state.page = page
        let store = TestStore(initialState: state) { LearningFeature() } withDependencies: {
            $0.date.now = timestamp
            $0.progressClient.save = { _ in }
        }

        for pair in activity.pairs.dropLast() {
            await store.send(.gameMatchChanged(
                activityID: activity.id,
                pairID: pair.id,
                rightPairID: pair.id
            )) {
                $0.gameDrafts[activity.id, default: GameDraft()].matches[pair.id] = pair.id
            }
        }
        #expect(store.state.progress.activityResponses[activity.id] == nil)

        let last = try #require(activity.pairs.last)
        let expectedMatches = Dictionary(uniqueKeysWithValues: activity.pairs.map { ($0.id, $0.id) })
        await store.send(.gameMatchChanged(
            activityID: activity.id,
            pairID: last.id,
            rightPairID: last.id
        )) {
            $0.gameDrafts.removeValue(forKey: activity.id)
            $0.isSaving = true
            $0.progress.activityResponses[activity.id] = GameResponse(
                activityID: activity.id,
                matches: expectedMatches,
                isCorrect: true,
                attempts: 1,
                answeredAt: timestamp
            )
        }
        await store.receive(.gameResponseSaveFinished(nil)) {
            $0.isSaving = false
        }
    }

    @Test
    func sidebarConceptSelectionInspectorAndFocusModeFormOneWorkspace() async throws {
        let content = BundledContentStore()
        let manifest = try content.loadManifest()
        let catalog = try content.loadKnowledgeCatalog()
        let page = try content.loadPage(id: .init(
            version: .v2,
            rawValue: "v2.s1.c1.p1"
        ))
        let conceptID = try #require(page.knowledgeConceptIDs.first)
        let store = TestStore(
            initialState: LearningFeature.State(pageID: page.id)
        ) {
            LearningFeature()
        }

        await store.send(.loadResponse(.loaded(
            manifest,
            catalog,
            page,
            .empty
        ))) {
            $0.manifest = manifest
            $0.knowledgeCatalog = catalog
            $0.page = page
            $0.selectedKnowledgeConceptID = conceptID
        }
        await store.send(.knowledgeConceptSelected(conceptID)) {
            $0.isInspectorPresented = true
        }
        await store.send(.focusModeButtonTapped) {
            $0.isFocusModeEnabled = true
            $0.isInspectorPresented = false
            $0.wasInspectorPresentedBeforeFocus = true
        }
        await store.send(.focusModeButtonTapped) {
            $0.isFocusModeEnabled = false
            $0.isInspectorPresented = true
        }
        await store.send(.sidebarVisibilityButtonTapped) {
            $0.sidebarMode = .hidden
        }
        await store.send(.inspectorDismissed) {
            $0.isInspectorPresented = false
            $0.wasInspectorPresentedBeforeFocus = false
        }
    }
}
