import Foundation

enum ContentClientError: Error, Equatable, Sendable {
    case chapterNotFound(ChapterID)
    case pageNotFound(chapterID: ChapterID, pageID: LearningPageID)
    case conceptNotFound(KnowledgeConceptID)
    case invalidBundledContent(resource: String, fieldPath: String, message: String)
}

extension ContentClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .chapterNotFound:
            "챕터 콘텐츠를 찾을 수 없습니다."
        case .pageNotFound:
            "요청한 학습 페이지를 찾을 수 없습니다."
        case .conceptNotFound:
            "요청한 지식 개념을 찾을 수 없습니다."
        case .invalidBundledContent:
            "앱에 포함된 학습 콘텐츠가 올바르지 않습니다."
        }
    }
}

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
