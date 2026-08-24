enum ContentClientError: Error, Equatable, Sendable {
    case chapterNotFound(ChapterID)
    case pageNotFound(chapterID: ChapterID, pageID: LearningPageID)
    case conceptNotFound(KnowledgeConceptID)
    case invalidBundledContent(resource: String, fieldPath: String, message: String)
}

enum PersistenceClientError: Error, Equatable, Sendable {
    case loadFailed(operation: String, message: String)
    case saveFailed(operation: String, message: String)
    case invalidStoredData(record: String, fieldPath: String, message: String)
}
