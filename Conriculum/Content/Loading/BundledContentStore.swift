import Foundation

struct BundledContentResource: BundledJSONResource, Equatable, Sendable {
    let name: String
    let subdirectory: String

    static let manifest = Self(
        name: "manifest",
        subdirectory: "Content"
    )

    static let knowledgeCatalog = Self(
        name: "catalog",
        subdirectory: "Content/knowledge"
    )

    init(relativePath: String) {
        let url = URL(fileURLWithPath: relativePath)
        name = url.deletingPathExtension().lastPathComponent
        subdirectory = url.deletingLastPathComponent().path
    }

    private init(name: String, subdirectory: String) {
        self.name = name
        self.subdirectory = subdirectory
    }

    var relativePath: String { "\(subdirectory)/\(name).json" }

    func url(in bundle: Bundle) throws -> URL {
        if let nested = bundle.url(
            forResource: name,
            withExtension: "json",
            subdirectory: subdirectory
        ) {
            return nested
        }
        if let flattened = bundle.url(forResource: name, withExtension: "json") {
            return flattened
        }
        throw BundledContentResourceError.resourceNotFound(
            name: relativePath,
            bundlePath: bundle.bundlePath
        )
    }
}

@MainActor
final class BundledContentStore {
    private let bundle: Bundle
    private let decoder: ContentResourceDecoder
    private var cachedManifest: ContentManifest?
    private var cachedKnowledgeCatalog: KnowledgeCatalog?
    private var cachedPages: [String: LessonPage] = [:]

    init(
        bundle: Bundle = .main,
        decoder: ContentResourceDecoder? = nil
    ) {
        self.bundle = bundle
        self.decoder = decoder ?? ContentResourceDecoder()
    }

    func loadManifest() throws -> ContentManifest {
        if let cachedManifest { return cachedManifest }
        let manifest = try decoder.decodeResource(
            ContentManifest.self,
            from: BundledContentResource.manifest,
            in: bundle
        )
        try ContentValidator().validate(manifest: manifest)
        cachedManifest = manifest
        return manifest
    }

    func loadKnowledgeCatalog() throws -> KnowledgeCatalog {
        if let cachedKnowledgeCatalog { return cachedKnowledgeCatalog }
        let catalog = try decoder.decodeResource(
            KnowledgeCatalog.self,
            from: BundledContentResource.knowledgeCatalog,
            in: bundle
        )
        try ContentValidator().validate(
            catalog: catalog,
            manifest: loadManifest()
        )
        cachedKnowledgeCatalog = catalog
        return catalog
    }

    func loadPage(id: String) throws -> LessonPage {
        if let cached = cachedPages[id] { return cached }

        let manifest = try loadManifest()
        guard let reference = manifest.pageReference(id: id) else {
            throw ContentError.pageNotFound(id)
        }
        let page = try decoder.decodeResource(
            LessonPage.self,
            from: BundledContentResource(relativePath: reference.resource),
            in: bundle
        )
        try ContentValidator().validate(page: page, reference: reference)
        cachedPages[id] = page
        return page
    }
}

enum ContentError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedSchema(Int)
    case duplicateID(String)
    case invalidOrder(String)
    case invalidReference(String)
    case pageNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version): "지원하지 않는 콘텐츠 schema \(version)입니다."
        case let .duplicateID(id): "중복된 콘텐츠 ID입니다: \(id)"
        case let .invalidOrder(path): "콘텐츠 순서가 연속적이지 않습니다: \(path)"
        case let .invalidReference(path): "콘텐츠 참조가 유효하지 않습니다: \(path)"
        case let .pageNotFound(id): "페이지를 찾을 수 없습니다: \(id)"
        }
    }
}
