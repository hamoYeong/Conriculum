import Foundation

struct V2BundledResource: BundledJSONResource, Equatable, Sendable {
    let name: String
    let subdirectory: String

    static let manifest = Self(
        name: "manifest",
        subdirectory: "Content/v2"
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
final class V2BundledContentStore {
    private let bundle: Bundle
    private let decoder: ContentResourceDecoder
    private var cachedManifest: V2ContentManifest?
    private var cachedPages: [String: V2LearningPage] = [:]

    init(
        bundle: Bundle = .main,
        decoder: ContentResourceDecoder? = nil
    ) {
        self.bundle = bundle
        self.decoder = decoder ?? ContentResourceDecoder()
    }

    func loadManifest() throws -> V2ContentManifest {
        if let cachedManifest { return cachedManifest }
        let manifest = try decoder.decodeResource(
            V2ContentManifest.self,
            from: V2BundledResource.manifest,
            in: bundle
        )
        try V2ContentValidator().validate(manifest: manifest)
        cachedManifest = manifest
        return manifest
    }

    func loadPage(id: VersionedContentID) throws -> V2LearningPage {
        guard id.version == .v2 else {
            throw V2ContentError.wrongVersion(id.version)
        }
        if let cached = cachedPages[id.rawValue] { return cached }

        let manifest = try loadManifest()
        guard let reference = manifest.pageReference(id: id.rawValue) else {
            throw V2ContentError.pageNotFound(id.rawValue)
        }
        let page = try decoder.decodeResource(
            V2LearningPage.self,
            from: V2BundledResource(relativePath: reference.resource),
            in: bundle
        )
        try V2ContentValidator().validate(page: page, reference: reference)
        cachedPages[id.rawValue] = page
        return page
    }
}

enum V2ContentError: Error, Equatable, LocalizedError, Sendable {
    case wrongVersion(ContentVersion)
    case unsupportedSchema(Int)
    case duplicateID(String)
    case invalidOrder(String)
    case invalidReference(String)
    case pageNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .wrongVersion(version): "ver.2 제공자에 \(version.rawValue) 요청이 전달되었습니다."
        case let .unsupportedSchema(version): "지원하지 않는 ver.2 schema \(version)입니다."
        case let .duplicateID(id): "중복된 ver.2 콘텐츠 ID입니다: \(id)"
        case let .invalidOrder(path): "ver.2 콘텐츠 순서가 연속적이지 않습니다: \(path)"
        case let .invalidReference(path): "ver.2 콘텐츠 참조가 유효하지 않습니다: \(path)"
        case let .pageNotFound(id): "ver.2 페이지를 찾을 수 없습니다: \(id)"
        }
    }
}
