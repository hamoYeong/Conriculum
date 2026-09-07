import Foundation

/// 번들 안의 JSON 주소를 콘텐츠 세대와 무관하게 해석하는 공용 계약.
protocol BundledJSONResource: Sendable {
    var relativePath: String { get }
    func url(in bundle: Bundle) throws -> URL
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
