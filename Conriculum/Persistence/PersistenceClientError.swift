import Foundation

enum PersistenceClientError: Error, Equatable, Sendable {
    case loadFailed(operation: String, message: String)
    case saveFailed(operation: String, message: String)
    case invalidStoredData(record: String, fieldPath: String, message: String)
}

extension PersistenceClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .loadFailed:
            "저장된 학습 기록을 불러오지 못했습니다."
        case .saveFailed:
            "학습 기록을 저장하지 못했습니다."
        case .invalidStoredData:
            "저장된 학습 기록이 올바르지 않습니다."
        }
    }
}
