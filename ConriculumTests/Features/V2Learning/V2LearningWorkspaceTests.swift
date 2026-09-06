import ComposableArchitecture
import Testing

@testable import Conriculum

@MainActor
struct V2LearningWorkspaceTests {
    @Test
    func sidebarConceptSelectionInspectorAndFocusModeFormOneWorkspace() async throws {
        let content = V2BundledContentStore()
        let manifest = try content.loadManifest()
        let catalog = try content.loadKnowledgeCatalog()
        let page = try content.loadPage(id: .init(
            version: .v2,
            rawValue: "v2.s1.c1.p1"
        ))
        let conceptID = try #require(page.knowledgeConceptIDs.first)
        let store = TestStore(
            initialState: V2LearningFeature.State(pageID: page.id)
        ) {
            V2LearningFeature()
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
