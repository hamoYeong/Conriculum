import Foundation
import Testing

@testable import Conriculum

struct BundledContentResourceTests {
    @Test
    func chapterTwoResourceDecodesFromTheApplicationBundle() throws {
        let chapter = try decode(Chapter.self, from: .chapter02)
        let expectedPageIDs: [LearningPageID] = (1...8).map {
            LearningPageID(rawValue: "chapter-02-page-\(String(format: "%02d", $0))")
        }

        #expect(chapter.id == "chapter-02")
        #expect(chapter.overview.kind == .overview)
        #expect(chapter.pages.count == 8)
        #expect(chapter.progressPageIDs == expectedPageIDs)
        #expect(Set(chapter.pages.flatMap(\.sections).map(\.content.tag)) == Set(LearningSectionTag.allCases))
    }

    @Test
    func userFacingWorkspaceCopyDoesNotExposeInternalEnglishTerms() throws {
        let chapter = try decode(Chapter.self, from: .chapter02)
        let sections = chapter.allPages.flatMap(\.sections)

        for section in sections {
            switch section.content {
            case let .personalExpressionComparison(content):
                #expect(!content.inspectorLocation.lowercased().contains("inspector"))

            case let .personalKnowledgePromotion(content):
                #expect(!content.cancellationResult.lowercased().contains("revision"))

            default:
                break
            }
        }
    }

    @Test
    func knowledgeCatalogResourceDecodesFromTheApplicationBundle() throws {
        let catalog = try decode(KnowledgeCatalog.self, from: .valuesAndTypes)

        #expect(catalog.schemaVersion == 1)
        #expect(catalog.concepts.count == 22)
        #expect(catalog.relations.isEmpty == false)
    }

    @Test
    func identityManifestResourceDecodesFromTheApplicationBundle() throws {
        let manifest = try decode(ContentIdentityManifest.self, from: .contentIdentity)

        #expect(manifest.schemaVersion == 1)
        #expect(manifest.identities.contains {
            $0.kind == .chapter && $0.stableID == "chapter-02"
        })
        #expect(manifest.identities.filter { $0.kind == .page }.count == 9)
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from resource: BundledContentResource
    ) throws -> Value {
        let data = try Data(contentsOf: resource.url())
        return try JSONDecoder().decode(type, from: data)
    }
}
