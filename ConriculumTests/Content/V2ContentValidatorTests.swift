import Testing

@testable import Conriculum

struct V2ContentValidatorTests {
    @Test
    @MainActor
    func bundledManifestAndEveryPageDecodeIndependently() throws {
        let store = V2BundledContentStore()
        let manifest = try store.loadManifest()
        let knowledgeCatalog = try store.loadKnowledgeCatalog()
        let conceptIDs = Set(knowledgeCatalog.concepts.map(\.id))

        #expect(manifest.contentVersion == .v2)
        #expect(manifest.stages.map(\.kind) == [.game, .learning])
        #expect(manifest.stages.map { $0.chapters.count } == [9, 8])
        #expect(manifest.chapters.flatMap(\.pages).count == 68)
        #expect(knowledgeCatalog.id == "learning-system-v2-knowledge.ko-KR")
        #expect(knowledgeCatalog.collections.count == 17)
        #expect(knowledgeCatalog.concepts.isEmpty == false)
        var interactiveActivityCount = 0

        for reference in manifest.chapters.flatMap(\.pages) {
            let page = try store.loadPage(id: VersionedContentID(
                version: .v2,
                rawValue: reference.id
            ))
            #expect(page.id == reference.id)
            #expect(page.blocks.isEmpty == false)
            #expect(page.sourcePath.hasSuffix(".md"))
            #expect(page.knowledgeConceptIDs.isEmpty == false)
            #expect(page.knowledgeConceptIDs.allSatisfy(conceptIDs.contains))
            interactiveActivityCount += page.blocks.flatMap(\.activities).count
        }
        #expect(interactiveActivityCount == 252)
    }

    @Test
    func rejectsOverlappingV2Identifiers() throws {
        let page = V2PageReference(
            id: "v2.s1.c1.p1", order: 1, title: "페이지", goal: "목표",
            resource: "Content/v2/learning/Stage01/Chapter01/page-01.json"
        )
        let chapter = V2Chapter(
            id: "v2.s1.c1", stageID: "v2.s1", order: 1,
            title: "챕터", summary: "요약", pages: [page, page]
        )
        let manifest = V2ContentManifest(
            schemaVersion: 1, contentVersion: .v2,
            id: "learning-system-v2.ko-KR", locale: "ko-KR", title: "과정",
            stages: [V2Stage(
                id: "v2.s1", order: 1, title: "스테이지", summary: "요약",
                kind: .game, chapters: [chapter]
            )]
        )

        #expect(throws: V2ContentError.self) {
            try V2ContentValidator().validate(manifest: manifest)
        }
    }

    @Test
    func pageReferenceMustMatchDecodedPage() {
        let reference = V2PageReference(
            id: "v2.s1.c1.p1", order: 1, title: "페이지", goal: "목표",
            resource: "Content/v2/learning/Stage01/Chapter01/page-01.json"
        )
        let page = V2LearningPage(
            schemaVersion: 1, contentVersion: .v2, id: "v2.s1.c1.p2",
            stageID: "v2.s1", chapterID: "v2.s1.c1", order: 1,
            title: "페이지", goal: "목표", sourcePath: "source.md",
            blocks: [], termRefs: [], knowledgeConceptIDs: []
        )

        #expect(throws: V2ContentError.self) {
            try V2ContentValidator().validate(page: page, reference: reference)
        }
    }
}
