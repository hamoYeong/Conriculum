import Foundation
import Testing

@testable import Conriculum

// MARK: - Decoder가 저수준 오류를 콘텐츠 작성자 문맥으로 번역하는지 확인

struct ContentResourceDecoderTests {
    /// 필수 field 누락 오류에 resource 이름과 정확한 field path가 포함되는지 확인한다.
    @Test
    func missingFieldErrorIncludesResourceAndFieldPath() throws {
        let data = Data(#"{}"#.utf8)

        do {
            _ = try ContentResourceDecoder().decode(
                RequiredNameFixture.self,
                from: data,
                resourceName: "broken-content.json"
            )
            Issue.record("필수 field가 없는 fixture가 decoding되었다.")
        } catch let error as ContentResourceDecodingError {
            #expect(error.resource == "broken-content.json")
            #expect(error.fieldPath == "name")
            #expect(error.message.contains("missing"))
            #expect(error.description.contains("broken-content.json:name"))
        } catch {
            Issue.record("예상하지 못한 오류: \(error)")
        }
    }

    /// 지원하지 않는 tag가 schema 오류에서 resource-aware decode 오류로 변환되는지 확인한다.
    @Test
    func unsupportedTagErrorIncludesResourceAndTagPath() throws {
        let data = Data(#"{"tag":"webView","payload":{}}"#.utf8)

        do {
            _ = try ContentResourceDecoder().decode(
                LearningSectionContent.self,
                from: data,
                resourceName: "broken-section.json"
            )
            Issue.record("지원하지 않는 tag가 decoding되었다.")
        } catch let error as ContentResourceDecodingError {
            #expect(error.resource == "broken-section.json")
            #expect(error.fieldPath == "tag")
            #expect(error.message.contains("webView"))
        } catch {
            Issue.record("예상하지 못한 오류: \(error)")
        }
    }
}

/// `keyNotFound` 경로를 가장 작게 재현하기 위한 fixture.
private struct RequiredNameFixture: Decodable {
    let name: String
}

// MARK: - 다음 읽기: Conriculum/Content/Validation/ContentValidator.swift
