import Foundation

/// 앱 안에서 병렬 운영하는 콘텐츠 제품 경계.
enum ContentVersion: String, Codable, CaseIterable, Equatable, Sendable {
    case v1
    case v2

    var title: String {
        switch self {
        case .v1: "ver.1 기존 과정"
        case .v2: "ver.2 AI 코드 읽기"
        }
    }
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
