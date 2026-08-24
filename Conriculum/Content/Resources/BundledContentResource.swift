import Foundation

enum BundledContentResource: CaseIterable, Equatable, Sendable {
    case chapter02
    case valuesAndTypes
    case contentIdentity

    var name: String {
        switch self {
        case .chapter02: "chapter-02"
        case .valuesAndTypes: "values-and-types"
        case .contentIdentity: "content-identity"
        }
    }

    var subdirectory: String {
        switch self {
        case .chapter02: "Curriculum/Stage01/Chapter02"
        case .valuesAndTypes: "KnowledgeCatalog"
        case .contentIdentity: "ContentManifest"
        }
    }

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

enum BundledContentResourceError: Error, Equatable, Sendable, CustomStringConvertible {
    case resourceNotFound(name: String, bundlePath: String)

    var description: String {
        switch self {
        case let .resourceNotFound(name, bundlePath):
            "Bundled content resource '\(name)' was not found in '\(bundlePath)'"
        }
    }
}
