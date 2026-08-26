import Foundation
import Testing

@testable import Conriculum

// MARK: - 15. 실제 Bundle 리소스가 root model로 조립되는지 확인

struct BundledContentResourceTests {
    /// Chapter JSON이 hierarchy 전체와 8개 진도 page, 22개 section tag를 포함해 decode되는지 확인한다.
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

    /// 실제 사용자 문구에 내부 구현 용어가 새어 나오지 않는지 resource 수준에서 확인한다.
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

    /// 지식 catalog JSON이 versioned `KnowledgeCatalog`로 decode되는지 확인한다.
    @Test
    func knowledgeCatalogResourceDecodesFromTheApplicationBundle() throws {
        let catalog = try decode(KnowledgeCatalog.self, from: .valuesAndTypes)

        #expect(catalog.schemaVersion == 1)
        #expect(catalog.concepts.count == 22)
        #expect(catalog.relations.isEmpty == false)
    }

    /// identity manifest가 Chapter와 overview 포함 9개 Page의 stable ID를 추적하는지 확인한다.
    @Test
    func identityManifestResourceDecodesFromTheApplicationBundle() throws {
        let manifest = try decode(ContentIdentityManifest.self, from: .contentIdentity)

        #expect(manifest.schemaVersion == 1)
        #expect(manifest.identities.contains {
            $0.kind == .chapter && $0.stableID == "chapter-02"
        })
        #expect(manifest.identities.filter { $0.kind == .page }.count == 9)
    }

    /// 이 테스트의 관심사인 Bundle URL과 기본 JSON decode만 수행하는 최소 호출 helper.
    /// 작성자용 오류 번역은 뒤의 `ContentResourceDecoderTests`에서 별도로 확인한다.
    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from resource: BundledContentResource
    ) throws -> Value {
        let data = try Data(contentsOf: resource.url())
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - 다음 읽기: Conriculum/Content/Decoding/ContentResourceDecoder.swift
