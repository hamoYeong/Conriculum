import Foundation
import Testing

@testable import Conriculum

struct ContentResourceDecoderTests {
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

private struct RequiredNameFixture: Decodable {
    let name: String
}
