import Foundation

struct ContentResourceDecoder: Sendable {
    func decode<Value: Decodable>(
        _ type: Value.Type,
        from resource: BundledContentResource,
        in bundle: Bundle = .main
    ) throws -> Value {
        let url = try resource.url(in: bundle)
        let data = try Data(contentsOf: url)
        return try decode(type, from: data, resourceName: url.lastPathComponent)
    }

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

    private func formattedPath(_ components: [String]) -> String {
        components.isEmpty ? "<root>" : components.joined(separator: ".")
    }
}

struct ContentResourceDecodingError: Error, Equatable, Sendable, CustomStringConvertible {
    let resource: String
    let fieldPath: String
    let message: String

    var description: String {
        "\(resource):\(fieldPath): \(message)"
    }
}
