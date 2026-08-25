import ComposableArchitecture
import Testing

@testable import Conriculum

@MainActor
struct LearningWorkspaceFeatureTests {
    @Test
    func chapterPageChangeRefreshesTheKnowledgeContext() async {
        let pageOne: LearningPageID = "chapter-02-page-01"
        let pageTwo: LearningPageID = "chapter-02-page-02"
        let store = TestStore(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: pageOne
            )
        ) {
            LearningWorkspaceFeature()
        }

        await store.send(.chapter(.currentPageChanged(pageTwo))) {
            $0.chapter.currentPageID = pageTwo
        }
        await store.receive(
            .chapter(.delegate(.currentPageChanged(pageTwo)))
        )
        await store.receive(.knowledgeContext(.pageChanged(pageTwo))) {
            $0.knowledgeContext.currentPageID = pageTwo
        }
        await store.receive(
            .knowledgeContext(.reloadRequested(.pageChanged))
        ) {
            $0.knowledgeContext.lastReloadReason = .pageChanged
            $0.knowledgeContext.reloadRequestCount = 1
        }
    }

    @Test
    func personalizationResultRefreshesOnlyTheKnowledgeChild() async {
        let pageID: LearningPageID = "chapter-02-page-03"
        let store = TestStore(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: pageID
            )
        ) {
            LearningWorkspaceFeature()
        }

        await store.send(.knowledgeContext(.personalizationSaved))
        await store.receive(
            .knowledgeContext(.delegate(.personalizationSaved))
        )
        await store.receive(
            .knowledgeContext(.reloadRequested(.personalizationSaved))
        ) {
            $0.knowledgeContext.lastReloadReason = .personalizationSaved
            $0.knowledgeContext.reloadRequestCount = 1
        }
    }

    @Test
    func homeButtonDelegatesWithoutOwningAppRouting() async {
        let store = TestStore(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: "chapter-02-overview"
            )
        ) {
            LearningWorkspaceFeature()
        }

        await store.send(.homeButtonTapped)
        await store.receive(.delegate(.homeRequested))
    }
}
