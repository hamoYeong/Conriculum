import Foundation

enum PersistenceMappingSupport {
    static func validateIdentifier(
        _ value: String,
        record: String,
        fieldPath: String
    ) throws {
        guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw invalid(
                record: record,
                fieldPath: fieldPath,
                message: "must contain a stable identifier"
            )
        }
    }

    static func encode<Value: Encodable>(
        _ value: Value,
        record: String,
        fieldPath: String
    ) throws -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(value)
        } catch {
            throw invalid(
                record: record,
                fieldPath: fieldPath,
                message: "could not encode the domain value"
            )
        }
    }

    static func decode<Value: Decodable>(
        _ type: Value.Type,
        from data: Data,
        record: String,
        fieldPath: String
    ) throws -> Value {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw invalid(
                record: record,
                fieldPath: fieldPath,
                message: "does not contain a valid encoded domain value"
            )
        }
    }

    static func storageID(
        value: String,
        namespace: String
    ) -> String {
        "\(namespace):\(value.utf8.count):\(value)"
    }

    static func invalid(
        record: String,
        fieldPath: String,
        message: String
    ) -> PersistenceClientError {
        .invalidStoredData(
            record: record,
            fieldPath: fieldPath,
            message: message
        )
    }
}
