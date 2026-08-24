struct KnowledgeCatalog: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let id: String
    let title: String
    let concepts: [KnowledgeConcept]
    let relations: [KnowledgeRelation]
}

struct ContentIdentityManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let identities: [ContentIdentity]
}

struct ContentIdentity: Codable, Equatable, Sendable {
    let kind: ContentIdentityKind
    let stableID: String
    let sourcePath: String
}

enum ContentIdentityKind: String, Codable, CaseIterable, Equatable, Sendable {
    case learningPath
    case stage
    case chapter
    case page
    case knowledgeConcept
}
