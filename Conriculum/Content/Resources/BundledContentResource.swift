import Foundation

// MARK: - 11. 앱 Bundle에 포함된 JSON 리소스의 주소

/// 파일명과 하위 경로를 한 값으로 묶어 호출부에 문자열 주소가 흩어지지 않게 한다.
/// Chapter 리소스는 공용 naming convention으로 만들므로 Chapter별 enum case가 필요 없다.
struct BundledContentResource: Equatable, Sendable {
    /// 확장자를 제외한 실제 JSON 파일명.
    let name: String

    /// Xcode resource group 안에서 기대하는 논리적 하위 경로.
    let subdirectory: String

    /// Stage·Chapter 번호를 `Stage01/Chapter03/chapter-03.json` 같은 공용 주소로 바꾼다.
    static func chapter(
        stageNumber: Int,
        chapterNumber: Int
    ) -> Self {
        let stage = String(format: "%02d", stageNumber)
        let chapter = String(format: "%02d", chapterNumber)
        return Self(
            name: "chapter-\(chapter)",
            subdirectory: "Curriculum/Stage\(stage)/Chapter\(chapter)"
        )
    }

    /// Chapter 2를 직접 decode하는 기존 fixture와 preview용 별칭.
    static let chapter02 = chapter(stageNumber: 1, chapterNumber: 2)

    static let valuesAndTypes = Self(
        name: "values-and-types",
        subdirectory: "KnowledgeCatalog"
    )

    static let contentIdentity = Self(
        name: "content-identity",
        subdirectory: "ContentManifest"
    )

    /// Validation 오류와 진단에 사용하는 Bundle 기준 상대 경로.
    var relativePath: String {
        "\(subdirectory)/\(name).json"
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
            name: relativePath,
            bundlePath: bundle.bundlePath
        )
    }
}

/// Chapter stable ID와 실제 번들 리소스의 연결을 콘텐츠 등록 지점 한곳에 모은다.
struct BundledChapterRegistration: Equatable, Sendable {
    let chapterID: ChapterID
    let resource: BundledContentResource
}

extension BundledContentResource {
    /// 새 Chapter를 번들에 추가할 때 화면·feature 코드 대신 이 목록만 확장한다.
    static let chapterRegistrations: [BundledChapterRegistration] = [
        BundledChapterRegistration(
            chapterID: "chapter-02",
            resource: .chapter(stageNumber: 1, chapterNumber: 2)
        ),
        BundledChapterRegistration(
            chapterID: "chapter-03",
            resource: .chapter(stageNumber: 1, chapterNumber: 3)
        ),
        BundledChapterRegistration(
            chapterID: "chapter-04",
            resource: .chapter(stageNumber: 1, chapterNumber: 4)
        ),
    ]
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
