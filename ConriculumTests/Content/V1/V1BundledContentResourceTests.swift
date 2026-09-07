import Foundation
import Testing

@testable import Conriculum

// MARK: - 실제 Bundle 리소스가 root model로 조립되는지 확인

struct V1BundledContentResourceTests {
    /// V1Chapter JSON이 전체 hierarchy와 진도 page, 역할이 겹치지 않는 section vocabulary를 포함하는지 확인한다.
    @Test
    func chapterTwoResourceDecodesFromTheApplicationBundle() throws {
        let chapter = try decode(V1Chapter.self, from: .chapter02)
        let expectedPageIDs: [LearningPageID] = (1...9).map {
            LearningPageID(rawValue: "chapter-02-page-\(String(format: "%02d", $0))")
        }

        #expect(chapter.id == "chapter-02")
        #expect(chapter.overview.kind == .overview)
        #expect(chapter.pages.count == 9)
        #expect(chapter.progressPageIDs == expectedPageIDs)
        #expect(Set(chapter.pages.flatMap(\.sections).map(\.content.tag)) == Set(V1LearningSectionTag.allCases))
    }

    /// 공용 V1Chapter resource 규칙으로 V1Chapter의 overview와 lesson을 찾아 decode하는지 확인한다.
    @Test
    func chapterThreeResourceDecodesFromTheApplicationBundle() throws {
        let resource = V1BundledContentResource.chapter(
            stageNumber: 1,
            chapterNumber: 3
        )
        let chapter = try decode(V1Chapter.self, from: resource)
        let expectedPageIDs: [LearningPageID] = (1...9).map {
            LearningPageID(rawValue: "chapter-03-page-\(String(format: "%02d", $0))")
        }

        #expect(chapter.id == "chapter-03")
        #expect(chapter.order == 3)
        #expect(chapter.overview.id == "chapter-03-overview")
        #expect(chapter.progressPageIDs == expectedPageIDs)
        #expect(chapter.pages.last?.sections.contains {
            $0.content.tag == .semanticChunkReading
        } == true)
    }

    /// 실제 사용자 문구에 내부 구현 용어가 새어 나오지 않는지 resource 수준에서 확인한다.
    @Test
    func userFacingWorkspaceCopyDoesNotExposeInternalEnglishTerms() throws {
        let chapter = try decode(V1Chapter.self, from: .chapter02)
        let sections = chapter.allPages.flatMap(\.sections)

        for section in sections {
            switch section.content {
            case let .personalKnowledgePromotion(content):
                #expect(!content.cancellationResult.lowercased().contains("revision"))

            default:
                break
            }
        }
    }

    @Test
    func chunkRemainsAnInternalIdentifierNotLearnerFacingCopy() throws {
        let resources: [V1BundledContentResource] = [
            .chapter02,
            .chapter(stageNumber: 1, chapterNumber: 3),
            .valuesAndTypes,
        ]
        for resource in resources {
            let object = try JSONSerialization.jsonObject(
                with: Data(contentsOf: resource.url())
            )
            assertLearnerFacingCopy(object)
        }
    }

    private func assertLearnerFacingCopy(_ value: Any, key: String = "") {
        // ID와 코드, 디코딩 태그는 학습 문구가 아닌 내부 계약이다.
        guard key != "id", !key.hasSuffix("ID"), !key.hasSuffix("IDs"),
              key != "code", key != "tag" else { return }
        if let text = value as? String {
            #expect(!text.localizedCaseInsensitiveContains("chunk"), "사용자 문구: \(text)")
        } else if let object = value as? [String: Any] {
            for (key, value) in object {
                assertLearnerFacingCopy(value, key: key)
            }
        } else if let values = value as? [Any] {
            for value in values {
                assertLearnerFacingCopy(value, key: key)
            }
        }
    }

    /// 지식 catalog JSON이 versioned `KnowledgeCatalog`로 decode되는지 확인한다.
    @Test
    func knowledgeCatalogResourceDecodesFromTheApplicationBundle() throws {
        let catalog = try decode(KnowledgeCatalog.self, from: .valuesAndTypes)
        let expectedCollectionIDs: [KnowledgeCollectionID] = [
            "collection-01-problem-solving",
            "collection-02-values-and-types",
            "collection-03-expressions-and-operations",
            "collection-04-execution-flow",
            "collection-05-functions-and-abstraction",
            "collection-07-type-modeling",
            "collection-12-swiftui-interface",
        ]
        let membershipIDs = catalog.collections.flatMap(\.conceptIDs)
        let hasCompletePresentationMetadata = catalog.collections.allSatisfy {
            $0.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                && $0.systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }

        #expect(catalog.schemaVersion == 2)
        #expect(catalog.collections.map(\.id) == expectedCollectionIDs)
        #expect(catalog.collections.map(\.order) == [1, 2, 3, 4, 5, 7, 12])
        #expect(catalog.collections.map(\.title) == [
            "문제 해결과 컴퓨팅 사고",
            "값과 타입",
            "표현식과 연산",
            "실행 흐름",
            "함수와 추상화",
            "타입 모델링",
            "SwiftUI와 사용자 인터페이스",
        ])
        #expect(hasCompletePresentationMetadata)
        #expect(catalog.concepts.count == 36)
        #expect(catalog.concepts.contains { $0.id == "concept-semantic-chunk-reading" })
        #expect(membershipIDs.count == catalog.concepts.count)
        #expect(Set(membershipIDs) == Set(catalog.concepts.map(\.id)))
        #expect(catalog.relations.isEmpty == false)
    }

    /// identity manifest가 모든 V1Chapter와 Page의 stable ID를 추적하는지 확인한다.
    @Test
    func identityManifestResourceDecodesFromTheApplicationBundle() throws {
        let manifest = try decode(V1ContentIdentityManifest.self, from: .contentIdentity)

        #expect(manifest.schemaVersion == 1)
        #expect(manifest.identities.contains {
            $0.kind == .chapter && $0.stableID == "chapter-02"
        })
        #expect(manifest.identities.filter { $0.kind == .chapter }.count == 3)
        #expect(manifest.identities.filter { $0.kind == .page }.count == 30)
    }

    /// 이 테스트의 관심사인 Bundle URL과 기본 JSON decode만 수행하는 최소 호출 helper.
    /// 작성자용 오류 번역은 뒤의 `V1ContentResourceDecoderTests`에서 별도로 확인한다.
    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from resource: V1BundledContentResource
    ) throws -> Value {
        let data = try Data(contentsOf: resource.url())
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - 다음 읽기: Conriculum/Content/Decoding/ContentResourceDecoder.swift
