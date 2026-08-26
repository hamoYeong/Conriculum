// MARK: - 10. JSON root를 Domain 값으로 감싸는 resource model

/// `values-and-types.json`의 root.
/// 공용 Concept와 Concept 간 Relation을 하나의 versioned catalog로 묶는다.
struct KnowledgeCatalog: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let id: String
    let title: String
    let concepts: [KnowledgeConcept]
    let relations: [KnowledgeRelation]
}

/// `content-identity.json`의 root.
/// 앱의 stable ID가 어떤 원본 콘텐츠 경로에서 왔는지 추적하는 목록이다.
struct ContentIdentityManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let identities: [ContentIdentity]
}

/// 한 Domain 객체의 종류·stable ID·원본 문서 경로를 연결한다.
struct ContentIdentity: Codable, Equatable, Sendable {
    let kind: ContentIdentityKind
    let stableID: String
    let sourcePath: String
}

/// manifest에서 source identity를 구분하는 최상위 콘텐츠 종류.
enum ContentIdentityKind: String, Codable, CaseIterable, Equatable, Sendable {
    case learningPath
    case stage
    case chapter
    case page
    case knowledgeConcept
}

// MARK: - 다음 읽기: Content/Resources/BundledContentResource.swift
