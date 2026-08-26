import Foundation

// MARK: - 11. 앱 Bundle에 포함된 JSON 리소스의 주소

/// 파일명 문자열을 호출부에 흩뜨리지 않고, 지원하는 bundled content를 case로 제한한다.
enum BundledContentResource: CaseIterable, Equatable, Sendable {
    case chapter02
    case valuesAndTypes
    case contentIdentity

    /// 확장자를 제외한 실제 JSON 파일명.
    var name: String {
        switch self {
        case .chapter02: "chapter-02"
        case .valuesAndTypes: "values-and-types"
        case .contentIdentity: "content-identity"
        }
    }

    /// Xcode resource group 안에서 기대하는 논리적 하위 경로.
    var subdirectory: String {
        switch self {
        case .chapter02: "Curriculum/Stage01/Chapter02"
        case .valuesAndTypes: "KnowledgeCatalog"
        case .contentIdentity: "ContentManifest"
        }
    }

    /// Bundle에서 리소스 URL을 찾는다.
    /// 먼저 하위 경로를 시도하고, build 과정에서 flatten된 Bundle도 지원한 뒤 명확한 오류를 낸다.
    func url(in bundle: Bundle = .main) throws -> URL {
        if let nestedURL = bundle.url(
            forResource: name,
            withExtension: "json",
            subdirectory: subdirectory
        ) {
            return nestedURL
        }

        if let flattenedURL = bundle.url(forResource: name, withExtension: "json") {
            return flattenedURL
        }

        throw BundledContentResourceError.resourceNotFound(
            name: "\(subdirectory)/\(name).json",
            bundlePath: bundle.bundlePath
        )
    }
}

/// 어떤 리소스를 어느 Bundle에서 찾지 못했는지 호출자에게 전달한다.
enum BundledContentResourceError: Error, Equatable, Sendable, CustomStringConvertible {
    case resourceNotFound(name: String, bundlePath: String)

    var description: String {
        switch self {
        case let .resourceNotFound(name, bundlePath):
            "Bundled content resource '\(name)' was not found in '\(bundlePath)'"
        }
    }
}

// MARK: - 다음 읽기: Resources/KnowledgeCatalog/values-and-types.json
// MARK: - 그다음: Resources/Curriculum/Stage01/Chapter02/chapter-02.json
// MARK: - 그다음: Resources/ContentManifest/content-identity.json
// MARK: - JSON 확인 후: ConriculumTests/Content/BundledContentResourceTests.swift
