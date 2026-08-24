import Foundation

@MainActor
final class BundledContentStore {
    private struct Snapshot: Sendable {
        let chapter: Chapter
        let catalog: KnowledgeCatalog
    }

    private let bundle: Bundle
    private var cachedSnapshot: Snapshot?

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadChapter(_ chapterID: ChapterID) throws -> Chapter {
        let chapter = try snapshot().chapter
        guard chapter.id == chapterID else {
            throw ContentClientError.chapterNotFound(chapterID)
        }
        return chapter
    }

    func loadPage(
        chapterID: ChapterID,
        pageID: LearningPageID
    ) throws -> LearningPage {
        let chapter = try loadChapter(chapterID)
        guard let page = chapter.allPages.first(where: { $0.id == pageID }) else {
            throw ContentClientError.pageNotFound(
                chapterID: chapterID,
                pageID: pageID
            )
        }
        return page
    }

    func loadCatalog() throws -> KnowledgeCatalog {
        try snapshot().catalog
    }

    func loadConcept(_ conceptID: KnowledgeConceptID) throws -> KnowledgeConcept {
        let catalog = try snapshot().catalog
        guard let concept = catalog.concepts.first(where: { $0.id == conceptID }) else {
            throw ContentClientError.conceptNotFound(conceptID)
        }
        return concept
    }

    func loadRelations(_ conceptID: KnowledgeConceptID) throws -> [KnowledgeRelation] {
        let catalog = try snapshot().catalog
        guard catalog.concepts.contains(where: { $0.id == conceptID }) else {
            throw ContentClientError.conceptNotFound(conceptID)
        }

        return catalog.relations.filter {
            $0.sourceConceptID == conceptID || $0.targetConceptID == conceptID
        }
    }

    private func snapshot() throws -> Snapshot {
        if let cachedSnapshot {
            return cachedSnapshot
        }

        let decoder = ContentResourceDecoder()
        do {
            let chapter = try decoder.decode(
                Chapter.self,
                from: .chapter02,
                in: bundle
            )
            let catalog = try decoder.decode(
                KnowledgeCatalog.self,
                from: .valuesAndTypes,
                in: bundle
            )
            let identityManifest = try decoder.decode(
                ContentIdentityManifest.self,
                from: .contentIdentity,
                in: bundle
            )
            try ContentValidator().validate(
                chapter: chapter,
                catalog: catalog,
                identityManifest: identityManifest
            )

            let snapshot = Snapshot(chapter: chapter, catalog: catalog)
            cachedSnapshot = snapshot
            return snapshot
        } catch let error as ContentResourceDecodingError {
            throw ContentClientError.invalidBundledContent(
                resource: error.resource,
                fieldPath: error.fieldPath,
                message: error.message
            )
        } catch let error as ContentValidationError {
            guard let issue = error.issues.first else {
                throw ContentClientError.invalidBundledContent(
                    resource: "bundled-content",
                    fieldPath: "<root>",
                    message: "validation failed without a reported issue"
                )
            }
            throw ContentClientError.invalidBundledContent(
                resource: issue.resource,
                fieldPath: issue.fieldPath,
                message: issue.message
            )
        } catch let error as BundledContentResourceError {
            throw ContentClientError.invalidBundledContent(
                resource: String(describing: error),
                fieldPath: "<root>",
                message: "required bundled resource is unavailable"
            )
        } catch {
            throw ContentClientError.invalidBundledContent(
                resource: bundle.bundlePath,
                fieldPath: "<root>",
                message: error.localizedDescription
            )
        }
    }
}
