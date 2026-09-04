import Foundation

struct KnowledgeContextSnapshot: Equatable, Sendable {
    struct RelationCreationContract: Equatable, Sendable {
        let sourceConceptIDs: [KnowledgeConceptID]
        let targetConceptIDs: [KnowledgeConceptID]
        let draftStatement: String
        let reasonPrompt: String
        let evidenceActivityID: LearningActivityID
    }

    struct ConceptItem: Equatable, Identifiable, Sendable {
        var id: KnowledgeConceptID { concept.id }

        let concept: KnowledgeConcept
        let personalRevision: PersonalConceptRevision?
        let revisionEvidenceActivityID: LearningActivityID?
        let role: KnowledgeLinkRole?
        let usage: String?
        let nearbyReason: String?

        var isChangedInChapter: Bool {
            personalRevision != nil
        }
    }

    let pageID: LearningPageID
    let pageTitle: String
    let currentQuestion: String
    let currentlyUsedSummary: String
    let changedKnowledgeSummary: String
    let emptyStateMessage: String
    let focusModeSummary: String
    let directConcepts: [ConceptItem]
    let changedConcepts: [ConceptItem]
    let nearbyConcepts: [ConceptItem]
    let availableConcepts: [KnowledgeConcept]
    let baseRelations: [KnowledgeRelation]
    let personalRelations: [PersonalKnowledgeRelation]
    let relationCreationContract: RelationCreationContract?
}

enum KnowledgeContextSnapshotComposerError: LocalizedError, Equatable {
    case missingPage(LearningPageID)
    case missingConcept(KnowledgeConceptID)

    var errorDescription: String? {
        switch self {
        case .missingPage:
            "현재 페이지의 지식 문맥을 찾을 수 없습니다."
        case .missingConcept:
            "연결된 지식 개념을 찾을 수 없습니다."
        }
    }
}

struct KnowledgeContextSnapshotComposer {
    func compose(
        chapter: Chapter,
        catalog: KnowledgeCatalog,
        pageID: LearningPageID,
        revisions: [PersonalConceptRevision],
        relations: [PersonalKnowledgeRelation] = []
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
        let revisionEvidenceByConcept = revisionEvidenceByConcept(in: page)

        // 페이지의 전체 지식 연결은 학습 콘텐츠와 관계 작성에 남겨 두고,
        // 사이드바에는 저자가 현재 문맥으로 고른 핵심 1개와 보조 최대 2개만 보낸다.
        let directConceptIDs = orderedUnique(
            page.knowledgeContext.currentlyUsedConceptIDs
        )
        let directConcepts = try directConceptIDs.map { conceptID in
            let link = linksByID[conceptID]
            return try item(
                conceptID: conceptID,
                conceptsByID: conceptsByID,
                latestRevisions: latestRevisions,
                revisionEvidenceActivityID: revisionEvidenceByConcept[
                    conceptID
                ],
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
                    revisionEvidenceActivityID: revisionEvidenceByConcept[
                        revision.conceptID
                    ],
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
                revisionEvidenceActivityID: revisionEvidenceByConcept[
                    nearby.conceptID
                ],
                role: linksByID[nearby.conceptID]?.role,
                usage: linksByID[nearby.conceptID]?.usage,
                nearbyReason: nearby.reason
            )
        }
        let personalRelations = latestRelationsByID(relations)
            .values
            .filter {
                conceptsByID[$0.sourceConceptID] != nil
                    && conceptsByID[$0.targetConceptID] != nil
            }
            .sorted(by: Self.relationOrder)

        return KnowledgeContextSnapshot(
            pageID: page.id,
            pageTitle: page.title,
            currentQuestion: currentQuestion(in: page),
            currentlyUsedSummary: page.knowledgeContext.currentlyUsedSummary,
            changedKnowledgeSummary: page.knowledgeContext
                .changedKnowledgeSummary,
            emptyStateMessage: page.knowledgeContext.emptyStateMessage,
            focusModeSummary: page.knowledgeContext.focusModeSummary,
            directConcepts: directConcepts,
            changedConcepts: changedConcepts,
            nearbyConcepts: nearbyConcepts,
            availableConcepts: catalog.concepts.sorted {
                ($0.title, $0.id.rawValue) < ($1.title, $1.id.rawValue)
            },
            baseRelations: catalog.relations,
            personalRelations: personalRelations,
            relationCreationContract: relationCreationContract(in: page)
        )
    }

    private func currentQuestion(in page: LearningPage) -> String {
        for section in page.sections {
            guard case let .learningCompass(content) = section.content else {
                continue
            }
            return content.coreQuestion
        }
        return page.goal
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
        revisionEvidenceActivityID: LearningActivityID?,
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
            revisionEvidenceActivityID: revisionEvidenceActivityID
                ?? latestRevisions[conceptID]?.evidenceActivityID,
            role: role,
            usage: usage,
            nearbyReason: nearbyReason
        )
    }

    private func revisionEvidenceByConcept(
        in page: LearningPage
    ) -> [KnowledgeConceptID: LearningActivityID] {
        var evidenceByConcept: [KnowledgeConceptID: LearningActivityID] = [:]

        for section in page.sections {
            guard case let .personalKnowledgePromotion(content) =
                section.content,
                let evidenceActivityID = content.evidenceActivityIDs.first
            else { continue }

            for conceptID in content.conceptIDs
            where evidenceByConcept[conceptID] == nil {
                evidenceByConcept[conceptID] = evidenceActivityID
            }
        }

        return evidenceByConcept
    }

    private func relationCreationContract(
        in page: LearningPage
    ) -> KnowledgeContextSnapshot.RelationCreationContract? {
        for section in page.sections {
            guard case let .personalKnowledgeRelation(content) =
                section.content,
                let evidenceActivityID = content.evidenceActivityIDs.first
            else { continue }

            return KnowledgeContextSnapshot.RelationCreationContract(
                sourceConceptIDs: content.sourceConceptIDs,
                targetConceptIDs: content.targetConceptIDs,
                draftStatement: content.draftStatement,
                reasonPrompt: content.reasonPrompt,
                evidenceActivityID: evidenceActivityID
            )
        }
        return nil
    }

    private func latestRelationsByID(
        _ relations: [PersonalKnowledgeRelation]
    ) -> [PersonalKnowledgeRelationID: PersonalKnowledgeRelation] {
        relations.reduce(into: [:]) { result, relation in
            guard let current = result[relation.id] else {
                result[relation.id] = relation
                return
            }
            if Self.relationOrder(lhs: relation, rhs: current) {
                result[relation.id] = relation
            }
        }
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

    nonisolated private static func relationOrder(
        lhs: PersonalKnowledgeRelation,
        rhs: PersonalKnowledgeRelation
    ) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id.rawValue > rhs.id.rawValue
    }
}
