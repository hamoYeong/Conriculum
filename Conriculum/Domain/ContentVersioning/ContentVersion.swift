import Foundation

/// 저장된 콘텐츠와 진행 기록의 정체성을 나타내는 제품 경계.
enum ContentVersion: String, Codable, Equatable, Sendable {
    case v2
}

/// 표시 문자열이 같아도 버전이 다르면 다른 콘텐츠가 되도록 만드는 전역 ID.
struct VersionedContentID: Hashable, Codable, Sendable {
    let version: ContentVersion
    let rawValue: String
}

/// 진행 기록 저장소가 반드시 사용하는 복합 키.
struct ProgressKey: Hashable, Codable, Sendable {
    let version: ContentVersion
    let contentID: String
}
