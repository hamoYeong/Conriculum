import AppKit
import ComposableArchitecture
import SwiftUI
import Testing
@testable import Conriculum

@MainActor
struct V1KnowledgeRevisitTests {
    @Test
    func everyCatalogConceptHasOneOrderedDeduplicatedRevisitList() throws {
        let content = V1BundledContentStore()
        let chapters = try content.loadChapters()
        let catalog = try content.loadCatalog()
        let pages = Dictionary(uniqueKeysWithValues: chapters.flatMap { chapter in
            chapter.allPages.map { ($0.id, (chapter, $0)) }
        })
        #expect(catalog.concepts.count == 36)
        #expect(catalog.concepts.contains { $0.id == "concept-example-validation" })
        for concept in catalog.concepts {
            let references = concept.revisitPages ?? []
            #expect(Set(references.map(\.pageID)).count == references.count)
            #expect(references == references.sorted {
                ($0.chapterOrder, $0.pageOrder ?? 0, $0.pageID.rawValue)
                    < ($1.chapterOrder, $1.pageOrder ?? 0, $1.pageID.rawValue)
            })
            for reference in references {
                let resolved = try #require(pages[reference.pageID])
                #expect(resolved.0.id == reference.chapterID)
                #expect(resolved.0.order == reference.chapterOrder)
                #expect(resolved.1.title == reference.pageTitle)
                #expect(!reference.connection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @Test
    func oldAndNewLearningPagesAreConnectedInBothDirections() throws {
        let catalog = try V1BundledContentStore().loadCatalog()
        let concepts = Dictionary(uniqueKeysWithValues: catalog.concepts.map { ($0.id, $0) })
        func pages(_ conceptID: KnowledgeConceptID) throws -> Set<LearningPageID> {
            Set(try #require(concepts[conceptID]).revisitPages?.map(\.pageID) ?? [])
        }
        #expect(try pages("concept-named-condition").isSuperset(of: [
            "chapter-02-page-04", "chapter-02-page-05",
            "chapter-03-page-04", "chapter-03-page-09",
            "chapter-04-page-06", "chapter-04-page-09",
        ]))
        #expect(try pages("concept-comparison-operator").isSuperset(of: [
            "chapter-02-page-06", "chapter-03-page-02",
            "chapter-03-page-03", "chapter-04-page-03",
        ]))
        #expect(try pages("concept-example-validation").contains("chapter-04-page-07"))
        #expect(try pages("concept-expression").contains("chapter-04-overview"))
    }

    @Test
    func revisitLinksDoNotUnlockKnowledgeWithoutVisitingTheLinkedLesson() throws {
        let content = V1BundledContentStore()
        let chapter = try content.loadChapter("chapter-02")
        let catalog = try content.loadCatalog()
        let visited = try #require(chapter.page(id: "chapter-02-page-04"))
        let learned = V1LearningExposure.directConceptIDs(page: visited)
        let snapshot = KnowledgeSystemSnapshotComposer().compose(
            catalog: catalog,
            revisions: [],
            personalRelations: [],
            learnedConceptIDs: learned
        )
        #expect(snapshot.conceptItem(id: "concept-identifier-naming")?.learningStatus == .learned)
        #expect(snapshot.conceptItem(id: "concept-named-condition")?.learningStatus == .unlearned)
    }

    @Test
    func selectingARevisitFromKnowledgeSystemOpensItsLearningPage() async throws {
        let catalog = try V1BundledContentStore().loadCatalog()
        let concept = try #require(catalog.concepts.first { $0.id == "concept-named-condition" })
        let reference = try #require(concept.revisitPages?.first { $0.pageID == "chapter-02-page-04" })
        var initial = AppFeature.State()
        initial.route = .knowledgeSystem
        initial.knowledgeSystem = KnowledgeSystemFeature.State()
        let store = TestStore(initialState: initial) { AppFeature() }
        await store.send(.knowledgeSystem(.learningPageTapped(reference)))
        await store.receive(.knowledgeSystem(.delegate(.v1LearningRequested(
            reference.chapterID,
            reference.pageID
        )))) {
            $0.knowledgeSystem = nil
            $0.v1Workspace = V1LearningWorkspaceFeature.State(
                chapterID: reference.chapterID,
                pageID: reference.pageID
            )
            $0.route = .v1Learning(chapterID: reference.chapterID)
        }
    }

    @Test
    func revisitSectionRendersAtNarrowWidth() throws {
        let catalog = try V1BundledContentStore().loadCatalog()
        let references = try #require(catalog.concepts.first {
            $0.id == "concept-named-condition"
        }?.revisitPages)
        let view = KnowledgeRevisitSection(references: references) { _ in }
            .padding(20)
            .frame(width: 360)
        let host = NSHostingView(rootView: view)
        let size = host.fittingSize
        #expect(size.width <= 361)
        #expect(size.height > 0 && size.height.isFinite)
    }
}
