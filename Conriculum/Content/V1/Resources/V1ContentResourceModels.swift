/// `content-identity.json`의 root.
/// 앱의 stable ID가 어떤 원본 콘텐츠 경로에서 왔는지 추적하는 목록이다.
struct V1ContentIdentityManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let identities: [V1ContentIdentity]
}

/// 한 Domain 객체의 종류·stable ID·원본 문서 경로를 연결한다.
struct V1ContentIdentity: Codable, Equatable, Sendable {
    let kind: V1ContentIdentityKind
    let stableID: String
    let sourcePath: String
}

/// manifest에서 source identity를 구분하는 최상위 콘텐츠 종류.
enum V1ContentIdentityKind: String, Codable, CaseIterable, Equatable, Sendable {
    case learningPath
    case stage
    case chapter
    case page
    case knowledgeConcept
}

// MARK: - 다음 읽기: Content/V1/Resources/V1BundledContentResource.swift
