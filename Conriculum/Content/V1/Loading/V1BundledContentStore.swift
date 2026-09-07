import Foundation

@MainActor
final class V1BundledContentStore {
    private struct SharedContent: Sendable {
        let catalog: KnowledgeCatalog
        let identityManifest: V1ContentIdentityManifest
    }

    private let bundle: Bundle
    private let chapterRegistrations: [V1BundledChapterRegistration]
    private var cachedChapters: [ChapterID: V1Chapter] = [:]
    private var cachedSharedContent: SharedContent?

    init(
        bundle: Bundle = .main,
        chapterRegistrations: [V1BundledChapterRegistration]? = nil
    ) {
        self.bundle = bundle
        self.chapterRegistrations = chapterRegistrations
            ?? V1BundledContentResource.chapterRegistrations
    }

    func loadChapters() throws -> [V1Chapter] {
        guard chapterRegistrations.isEmpty == false else {
            throw V1ContentClientError.noChaptersAvailable
        }

        return try chapterRegistrations
            .map { try loadChapter($0.chapterID) }
            .sorted {
                ($0.stageID.rawValue, $0.order, $0.id.rawValue)
                    < ($1.stageID.rawValue, $1.order, $1.id.rawValue)
            }
    }

    func loadChapter(_ chapterID: ChapterID) throws -> V1Chapter {
        if let cachedChapter = cachedChapters[chapterID] {
            return cachedChapter
        }

        guard let registration = chapterRegistrations.first(where: {
            $0.chapterID == chapterID
        }) else {
            throw V1ContentClientError.chapterNotFound(chapterID)
        }

        return try mapContentErrors {
            let decoder = ContentResourceDecoder()
            let chapter = try decoder.decode(
                V1Chapter.self,
                from: registration.resource,
                in: bundle
            )
            guard chapter.id == registration.chapterID else {
                throw V1ContentClientError.invalidBundledContent(
                    resource: registration.resource.relativePath,
                    fieldPath: "id",
                    message: "does not match its registered chapter ID"
                )
            }

            let sharedContent = try sharedContent()
            try V1ContentValidator().validate(
                chapter: chapter,
                catalog: sharedContent.catalog,
                identityManifest: sharedContent.identityManifest,
                chapterResource: registration.resource.relativePath,
                catalogResource: V1BundledContentResource.valuesAndTypes.relativePath,
                identityResource: V1BundledContentResource.contentIdentity.relativePath
            )

            cachedChapters[chapterID] = chapter
            return chapter
        }
    }

    func loadPage(
        chapterID: ChapterID,
        pageID: LearningPageID
    ) throws -> V1LearningPage {
        let chapter = try loadChapter(chapterID)
        guard let page = chapter.allPages.first(where: { $0.id == pageID }) else {
            throw V1ContentClientError.pageNotFound(
                chapterID: chapterID,
                pageID: pageID
            )
        }
        return page
    }

    func loadCatalog() throws -> KnowledgeCatalog {
        _ = try loadChapters()
        return try sharedContent().catalog
    }

    func loadConcept(_ conceptID: KnowledgeConceptID) throws -> KnowledgeConcept {
        let catalog = try loadCatalog()
        guard let concept = catalog.concepts.first(where: { $0.id == conceptID }) else {
            throw V1ContentClientError.conceptNotFound(conceptID)
        }
        return concept
    }

    func loadRelations(_ conceptID: KnowledgeConceptID) throws -> [KnowledgeRelation] {
        let catalog = try loadCatalog()
        guard catalog.concepts.contains(where: { $0.id == conceptID }) else {
            throw V1ContentClientError.conceptNotFound(conceptID)
        }

        return catalog.relations.filter {
            $0.sourceConceptID == conceptID || $0.targetConceptID == conceptID
        }
    }

    private func sharedContent() throws -> SharedContent {
        if let cachedSharedContent {
            return cachedSharedContent
        }

        let decoder = ContentResourceDecoder()
        let content = try SharedContent(
            catalog: decoder.decode(
                KnowledgeCatalog.self,
                from: V1BundledContentResource.valuesAndTypes,
                in: bundle
            ),
            identityManifest: decoder.decode(
                V1ContentIdentityManifest.self,
                from: V1BundledContentResource.contentIdentity,
                in: bundle
            )
        )
        cachedSharedContent = content
        return content
    }

    private func mapContentErrors<Value>(
        _ operation: () throws -> Value
    ) throws -> Value {
        do {
            return try operation()
        } catch let error as V1ContentClientError {
            throw error
        } catch let error as ContentResourceDecodingError {
            throw V1ContentClientError.invalidBundledContent(
                resource: error.resource,
                fieldPath: error.fieldPath,
                message: error.message
            )
        } catch let error as V1ContentValidationError {
            guard let issue = error.issues.first else {
                throw V1ContentClientError.invalidBundledContent(
                    resource: "bundled-content",
                    fieldPath: "<root>",
                    message: "validation failed without a reported issue"
                )
            }
            throw V1ContentClientError.invalidBundledContent(
                resource: issue.resource,
                fieldPath: issue.fieldPath,
                message: issue.message
            )
        } catch let error as BundledContentResourceError {
            throw V1ContentClientError.invalidBundledContent(
                resource: String(describing: error),
                fieldPath: "<root>",
                message: "required bundled resource is unavailable"
            )
        } catch {
            throw V1ContentClientError.invalidBundledContent(
                resource: bundle.bundlePath,
                fieldPath: "<root>",
                message: error.localizedDescription
            )
        }
    }
}
