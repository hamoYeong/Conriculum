import Foundation

// MARK: - Bundle JSON을 Domain으로 바꾸고 오류 문맥을 보강하는 경계

/// 콘텐츠 리소스 로딩과 `Decodable` 변환을 한곳에 모으는 stateless decoder.
struct ContentResourceDecoder: Sendable {
    /// typed resource를 Bundle에서 찾아 읽고 요청한 Domain 타입으로 decode한다.
    /// 앱의 실제 호출부가 사용하는 `Bundle → Data → Value` 진입점이다.
    func decode<Value: Decodable>(
        _ type: Value.Type,
        from resource: BundledContentResource,
        in bundle: Bundle = .main
    ) throws -> Value {
        let url = try resource.url(in: bundle)
        let data = try Data(contentsOf: url)
        return try decode(type, from: data, resourceName: url.lastPathComponent)
    }

    /// 이미 준비된 Data를 decode한다.
    /// 원래 `DecodingError`를 resource 이름과 정확한 field path가 있는 작성자용 오류로 번역한다.
    func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        resourceName: String
    ) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as UnsupportedLearningSectionTagError {
            throw ContentResourceDecodingError(
                resource: resourceName,
                fieldPath: formattedPath(error.codingPath),
                message: "unsupported section tag '\(error.tag)'"
            )
        } catch let DecodingError.keyNotFound(key, context) {
            throw ContentResourceDecodingError(
                resource: resourceName,
                fieldPath: formattedPath(context.codingPath + [key]),
                message: "required field is missing"
            )
        } catch let DecodingError.typeMismatch(type, context) {
            throw ContentResourceDecodingError(
                resource: resourceName,
                fieldPath: formattedPath(context.codingPath),
                message: "expected \(String(describing: type)): \(context.debugDescription)"
            )
        } catch let DecodingError.valueNotFound(type, context) {
            throw ContentResourceDecodingError(
                resource: resourceName,
                fieldPath: formattedPath(context.codingPath),
                message: "expected \(String(describing: type)): \(context.debugDescription)"
            )
        } catch let DecodingError.dataCorrupted(context) {
            throw ContentResourceDecodingError(
                resource: resourceName,
                fieldPath: formattedPath(context.codingPath),
                message: context.debugDescription
            )
        }
    }

    /// `CodingKey` 배열을 `pages[0].sections[2].content` 형태로 표시한다.
    private func formattedPath(_ codingPath: [any CodingKey]) -> String {
        var result = ""

        for key in codingPath {
            if let index = key.intValue {
                result += "[\(index)]"
            } else {
                if result.isEmpty == false {
                    result += "."
                }
                result += key.stringValue
            }
        }

        return result.isEmpty ? "<root>" : result
    }

    /// custom schema 오류가 가진 문자열 path에도 같은 출력 규칙을 적용한다.
    private func formattedPath(_ components: [String]) -> String {
        components.isEmpty ? "<root>" : components.joined(separator: ".")
    }
}

/// decode 실패가 발생한 리소스·field·원인을 한 줄로 보고하는 오류.
struct ContentResourceDecodingError: Error, Equatable, Sendable, CustomStringConvertible {
    let resource: String
    let fieldPath: String
    let message: String

    var description: String {
        "\(resource):\(fieldPath): \(message)"
    }
}

// MARK: - 다음 읽기: ConriculumTests/Content/ContentResourceDecoderTests.swift
// MARK: - 그다음: Content/Validation/ContentValidator.swift
