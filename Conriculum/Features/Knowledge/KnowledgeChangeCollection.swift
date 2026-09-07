import Foundation

struct KnowledgeChangeCollection: Equatable, Sendable {
    enum Confirmed: Equatable, Identifiable, Sendable {
        case revision(Revision)
        case relation(Relation)

        var id: String {
            switch self {
            case let .revision(revision):
                "revision-\(revision.id.rawValue)"
            case let .relation(relation):
                "relation-\(relation.id.rawValue)"
            }
        }

        var modifiedAt: Date {
            switch self {
            case let .revision(revision): revision.modifiedAt
            case let .relation(relation): relation.modifiedAt
            }
        }
    }

    struct Revision: Equatable, Sendable {
        let id: PersonalConceptRevisionID
        let conceptID: KnowledgeConceptID
        let conceptTitle: String
        let personalTitle: String?
        let explanation: String
        let exampleCount: Int
        let evidenceActivityID: LearningActivityID
        let modifiedAt: Date
    }

    struct Relation: Equatable, Sendable {
        let id: PersonalKnowledgeRelationID
        let sourceConceptID: KnowledgeConceptID
        let sourceConceptTitle: String
        let targetConceptID: KnowledgeConceptID
        let targetConceptTitle: String
        let statement: String
        let reason: String
        let evidenceActivityID: LearningActivityID
        let modifiedAt: Date
    }

    struct Pending: Equatable, Identifiable, Sendable {
        let id: KnowledgePersonalizationCandidateID
        let targetConceptID: KnowledgeConceptID
        let targetConceptTitle: String
        let connectedConceptTitles: [String]
        let draft: String
        let evidenceActivityID: LearningActivityID
        let createdAt: Date
    }

    let confirmed: [Confirmed]
    let pending: [Pending]
}

struct KnowledgeChangeCollectionComposer {
    func compose(
        concepts: [KnowledgeConcept],
        revisions: [PersonalConceptRevision],
        relations: [PersonalKnowledgeRelation],
        pendingReviews: [V1KnowledgePersonalizationReview]
    ) -> KnowledgeChangeCollection {
        let titlesByID = Dictionary(
            uniqueKeysWithValues: concepts.map { ($0.id, $0.title) }
        )
        let confirmedRevisions = latestRevisions(revisions).values.map {
            revision in
            KnowledgeChangeCollection.Confirmed.revision(
                KnowledgeChangeCollection.Revision(
                    id: revision.id,
                    conceptID: revision.conceptID,
                    conceptTitle: title(
                        for: revision.conceptID,
                        titlesByID: titlesByID
                    ),
                    personalTitle: revision.personalTitle,
                    explanation: revision.explanation,
                    exampleCount: revision.examples.count,
                    evidenceActivityID: revision.evidenceActivityID,
                    modifiedAt: revision.createdAt
                )
            )
        }
        let confirmedRelations = latestRelations(relations).values.map {
            relation in
            KnowledgeChangeCollection.Confirmed.relation(
                KnowledgeChangeCollection.Relation(
                    id: relation.id,
                    sourceConceptID: relation.sourceConceptID,
                    sourceConceptTitle: title(
                        for: relation.sourceConceptID,
                        titlesByID: titlesByID
                    ),
                    targetConceptID: relation.targetConceptID,
                    targetConceptTitle: title(
                        for: relation.targetConceptID,
                        titlesByID: titlesByID
                    ),
                    statement: relation.statement,
                    reason: relation.reason,
                    evidenceActivityID: relation.evidenceActivityID,
                    modifiedAt: relation.createdAt
                )
            )
        }
        let pending = latestPendingReviews(pendingReviews).values.map {
            review in
            KnowledgeChangeCollection.Pending(
                id: review.id,
                targetConceptID: review.targetConceptID,
                targetConceptTitle: title(
                    for: review.targetConceptID,
                    titlesByID: titlesByID
                ),
                connectedConceptTitles: review.candidate.conceptIDs.map {
                    title(for: $0, titlesByID: titlesByID)
                },
                draft: review.candidate.draft,
                evidenceActivityID: review.candidate.evidenceActivityID,
                createdAt: review.candidate.createdAt
            )
        }

        return KnowledgeChangeCollection(
            confirmed: (confirmedRevisions + confirmedRelations).sorted {
                if $0.modifiedAt != $1.modifiedAt {
                    return $0.modifiedAt > $1.modifiedAt
                }
                return $0.id < $1.id
            },
            pending: pending.sorted {
                if $0.createdAt != $1.createdAt {
                    return $0.createdAt > $1.createdAt
                }
                return $0.id.rawValue < $1.id.rawValue
            }
        )
    }

    private func latestRevisions(
        _ revisions: [PersonalConceptRevision]
    ) -> [KnowledgeConceptID: PersonalConceptRevision] {
        revisions.reduce(into: [:]) { result, revision in
            guard let current = result[revision.conceptID] else {
                result[revision.conceptID] = revision
                return
            }
            if revision.createdAt > current.createdAt
                || revision.createdAt == current.createdAt
                    && revision.id.rawValue > current.id.rawValue
            {
                result[revision.conceptID] = revision
            }
        }
    }

    private func latestRelations(
        _ relations: [PersonalKnowledgeRelation]
    ) -> [PersonalKnowledgeRelationID: PersonalKnowledgeRelation] {
        relations.reduce(into: [:]) { result, relation in
            guard let current = result[relation.id] else {
                result[relation.id] = relation
                return
            }
            if relation.createdAt > current.createdAt
                || relation.createdAt == current.createdAt
                    && relation.statement > current.statement
            {
                result[relation.id] = relation
            }
        }
    }

    private func latestPendingReviews(
        _ reviews: [V1KnowledgePersonalizationReview]
    ) -> [KnowledgeConceptID: V1KnowledgePersonalizationReview] {
        reviews.reduce(into: [:]) { result, review in
            guard let current = result[review.targetConceptID] else {
                result[review.targetConceptID] = review
                return
            }
            if review.candidate.createdAt > current.candidate.createdAt
                || review.candidate.createdAt == current.candidate.createdAt
                    && review.id.rawValue > current.id.rawValue
            {
                result[review.targetConceptID] = review
            }
        }
    }

    private func title(
        for conceptID: KnowledgeConceptID,
        titlesByID: [KnowledgeConceptID: String]
    ) -> String {
        titlesByID[conceptID] ?? conceptID.rawValue
    }
}
