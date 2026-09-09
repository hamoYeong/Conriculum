import Foundation

enum V1RecordMappingSupport {
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

    static func validateProfileID(
        _ storedProfileID: String,
        expected expectedProfileID: LocalProfileID,
        record: String
    ) throws {
        try validateIdentifier(
            storedProfileID,
            record: record,
            fieldPath: "profileID"
        )
        try validateIdentifier(
            expectedProfileID.rawValue,
            record: record,
            fieldPath: "profileID"
        )

        guard storedProfileID == expectedProfileID.rawValue else {
            throw invalid(
                record: record,
                fieldPath: "profileID",
                message: "does not belong to the requested local profile"
            )
        }
    }

    static func encode<Value: Encodable>(
        _ value: Value,
        record: String,
        fieldPath: String
    ) throws -> Data {
        do {
            return try JSONEncoder().encode(value)
        } catch {
            throw invalid(
                record: record,
                fieldPath: fieldPath,
                message: "could not encode the domain value: \(error.localizedDescription)"
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

    static func invalid(
        record: String,
        fieldPath: String,
        message: String
    ) -> V1PersistenceClientError {
        .invalidStoredData(
            record: record,
            fieldPath: fieldPath,
            message: message
        )
    }
}
