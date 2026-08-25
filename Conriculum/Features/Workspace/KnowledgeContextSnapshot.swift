import Foundation

struct KnowledgeContextSnapshot: Equatable, Sendable {
    struct ConceptItem: Equatable, Identifiable, Sendable {
        var id: KnowledgeConceptID { concept.id }

        let concept: KnowledgeConcept
        let personalRevision: PersonalConceptRevision?
        let role: KnowledgeLinkRole?
        let usage: String?
        let nearbyReason: String?

        var isChangedInChapter: Bool {
            personalRevision != nil
        }
    }

    let pageID: LearningPageID
    let pageTitle: String
    let currentlyUsedSummary: String
    let changedKnowledgeSummary: String
    let emptyStateMessage: String
    let focusModeSummary: String
    let directConcepts: [ConceptItem]
    let changedConcepts: [ConceptItem]
    let nearbyConcepts: [ConceptItem]
}

enum KnowledgeContextSnapshotComposerError: LocalizedError, Equatable {
    case missingPage(LearningPageID)
    case missingConcept(KnowledgeConceptID)

    var errorDescription: String? {
        switch self {
        case let .missingPage(pageID):
            "현재 페이지를 찾을 수 없습니다: \(pageID.rawValue)"
        case let .missingConcept(conceptID):
            "지식 개념을 찾을 수 없습니다: \(conceptID.rawValue)"
        }
    }
}

struct KnowledgeContextSnapshotComposer {
    func compose(
        chapter: Chapter,
        catalog: KnowledgeCatalog,
        pageID: LearningPageID,
        revisions: [PersonalConceptRevision]
    ) throws -> KnowledgeContextSnapshot {
        guard let page = chapter.page(id: pageID) else {
            throw KnowledgeContextSnapshotComposerError.missingPage(pageID)
        }

        let conceptsByID = Dictionary(
            uniqueKeysWithValues: catalog.concepts.map { ($0.id, $0) }
        )
        let chapterConceptIDs = Set(chapter.allPages.flatMap { page in
            page.knowledgeLinks.map(\.conceptID)
                + page.knowledgeContext.currentlyUsedConceptIDs
                + page.knowledgeContext.nearbyKnowledge.map(\.conceptID)
        })
        let latestRevisions = latestRevisionsByConcept(
            revisions.filter { chapterConceptIDs.contains($0.conceptID) }
        )
        let linksByID = Dictionary(
            page.knowledgeLinks.map { ($0.conceptID, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let directConceptIDs = orderedUnique(
            page.knowledgeContext.currentlyUsedConceptIDs
                + page.knowledgeLinks.map(\.conceptID)
        )
        let directConcepts = try directConceptIDs.map { conceptID in
            let link = linksByID[conceptID]
            return try item(
                conceptID: conceptID,
                conceptsByID: conceptsByID,
                latestRevisions: latestRevisions,
                role: link?.role,
                usage: link?.usage,
                nearbyReason: nil
            )
        }

        let changedConcepts = try latestRevisions.values
            .sorted(by: Self.revisionOrder)
            .map { revision in
                let link = linksByID[revision.conceptID]
                return try item(
                    conceptID: revision.conceptID,
                    conceptsByID: conceptsByID,
                    latestRevisions: latestRevisions,
                    role: link?.role,
                    usage: link?.usage,
                    nearbyReason: nil
                )
            }

        let nearbyConcepts = try page.knowledgeContext.nearbyKnowledge.map {
            nearby in
            try item(
                conceptID: nearby.conceptID,
                conceptsByID: conceptsByID,
                latestRevisions: latestRevisions,
                role: linksByID[nearby.conceptID]?.role,
                usage: linksByID[nearby.conceptID]?.usage,
                nearbyReason: nearby.reason
            )
        }

        return KnowledgeContextSnapshot(
            pageID: page.id,
            pageTitle: page.title,
            currentlyUsedSummary: page.knowledgeContext.currentlyUsedSummary,
            changedKnowledgeSummary: page.knowledgeContext
                .changedKnowledgeSummary,
            emptyStateMessage: page.knowledgeContext.emptyStateMessage,
            focusModeSummary: page.knowledgeContext.focusModeSummary,
            directConcepts: directConcepts,
            changedConcepts: changedConcepts,
            nearbyConcepts: nearbyConcepts
        )
    }

    static func chapterConceptIDs(in chapter: Chapter) -> [KnowledgeConceptID] {
        Set(chapter.allPages.flatMap { page in
            page.knowledgeLinks.map(\.conceptID)
                + page.knowledgeContext.currentlyUsedConceptIDs
                + page.knowledgeContext.nearbyKnowledge.map(\.conceptID)
        })
        .sorted { $0.rawValue < $1.rawValue }
    }

    private func item(
        conceptID: KnowledgeConceptID,
        conceptsByID: [KnowledgeConceptID: KnowledgeConcept],
        latestRevisions: [KnowledgeConceptID: PersonalConceptRevision],
        role: KnowledgeLinkRole?,
        usage: String?,
        nearbyReason: String?
    ) throws -> KnowledgeContextSnapshot.ConceptItem {
        guard let concept = conceptsByID[conceptID] else {
            throw KnowledgeContextSnapshotComposerError.missingConcept(
                conceptID
            )
        }
        return KnowledgeContextSnapshot.ConceptItem(
            concept: concept,
            personalRevision: latestRevisions[conceptID],
            role: role,
            usage: usage,
            nearbyReason: nearbyReason
        )
    }

    private func latestRevisionsByConcept(
        _ revisions: [PersonalConceptRevision]
    ) -> [KnowledgeConceptID: PersonalConceptRevision] {
        revisions.reduce(into: [:]) { result, revision in
            guard let current = result[revision.conceptID] else {
                result[revision.conceptID] = revision
                return
            }
            if Self.revisionOrder(lhs: revision, rhs: current) {
                result[revision.conceptID] = revision
            }
        }
    }

    private func orderedUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        return values.filter { seen.insert($0).inserted }
    }

    nonisolated private static func revisionOrder(
        lhs: PersonalConceptRevision,
        rhs: PersonalConceptRevision
    ) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id.rawValue > rhs.id.rawValue
    }
}
