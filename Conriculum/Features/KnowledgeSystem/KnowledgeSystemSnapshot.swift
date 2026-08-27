import Foundation

struct KnowledgeSystemSnapshot: Equatable, Sendable {
    struct CollectionItem: Equatable, Identifiable, Sendable {
        let id: KnowledgeCollectionID
        let order: Int
        let title: String
        let summary: String
        let systemImage: String
        let conceptIDs: [KnowledgeConceptID]
    }

    struct ConceptItem: Equatable, Identifiable, Sendable {
        var id: KnowledgeConceptID { concept.id }

        let concept: KnowledgeConcept
        let collectionID: KnowledgeCollectionID
        let latestRevision: PersonalConceptRevision?
    }

    let catalogID: String
    let title: String
    let collections: [CollectionItem]
    let concepts: [ConceptItem]
    let baseRelations: [KnowledgeRelation]
    let personalRelations: [PersonalKnowledgeRelation]

    func conceptItem(
        id: KnowledgeConceptID
    ) -> ConceptItem? {
        concepts.first { $0.id == id }
    }

    func collection(
        id: KnowledgeCollectionID
    ) -> CollectionItem? {
        collections.first { $0.id == id }
    }

    func baseRelations(
        for conceptID: KnowledgeConceptID
    ) -> [KnowledgeRelation] {
        baseRelations.filter {
            $0.sourceConceptID == conceptID
                || $0.targetConceptID == conceptID
        }
    }

    func personalRelations(
        for conceptID: KnowledgeConceptID
    ) -> [PersonalKnowledgeRelation] {
        personalRelations.filter {
            $0.sourceConceptID == conceptID
                || $0.targetConceptID == conceptID
        }
    }

    func relatedConceptIDs(
        for conceptID: KnowledgeConceptID
    ) -> [KnowledgeConceptID] {
        let baseIDs = baseRelations(for: conceptID).map {
            $0.sourceConceptID == conceptID
                ? $0.targetConceptID
                : $0.sourceConceptID
        }
        let personalIDs = personalRelations(for: conceptID).map {
            $0.sourceConceptID == conceptID
                ? $0.targetConceptID
                : $0.sourceConceptID
        }
        let orderByID = Dictionary(
            uniqueKeysWithValues: concepts.enumerated().map {
                ($0.element.id, $0.offset)
            }
        )

        return Array(Set(baseIDs + personalIDs)).sorted {
            orderByID[$0, default: .max]
                < orderByID[$1, default: .max]
        }
    }
}

struct KnowledgeSystemSnapshotComposer: Sendable {
    func compose(
        catalog: KnowledgeCatalog,
        revisions: [PersonalConceptRevision],
        personalRelations: [PersonalKnowledgeRelation]
    ) -> KnowledgeSystemSnapshot {
        let conceptIDs = Set(catalog.concepts.map(\.id))
        let collectionByConceptID = collectionMemberships(
            in: catalog
        )
        let latestRevisionByConceptID = latestRevisions(
            revisions,
            allowedConceptIDs: conceptIDs
        )
        let uniquePersonalRelations = deduplicatedRelations(
            personalRelations,
            allowedConceptIDs: conceptIDs
        )

        return KnowledgeSystemSnapshot(
            catalogID: catalog.id,
            title: catalog.title,
            collections: catalog.collections.map {
                KnowledgeSystemSnapshot.CollectionItem(
                    id: $0.id,
                    order: $0.order,
                    title: $0.title,
                    summary: $0.summary,
                    systemImage: $0.systemImage,
                    conceptIDs: $0.conceptIDs.filter(conceptIDs.contains)
                )
            },
            concepts: catalog.concepts.compactMap { concept in
                guard let collectionID = collectionByConceptID[concept.id]
                else { return nil }
                return KnowledgeSystemSnapshot.ConceptItem(
                    concept: concept,
                    collectionID: collectionID,
                    latestRevision: latestRevisionByConceptID[concept.id]
                )
            },
            baseRelations: catalog.relations.filter {
                conceptIDs.contains($0.sourceConceptID)
                    && conceptIDs.contains($0.targetConceptID)
            },
            personalRelations: uniquePersonalRelations
        )
    }

    private func collectionMemberships(
        in catalog: KnowledgeCatalog
    ) -> [KnowledgeConceptID: KnowledgeCollectionID] {
        var memberships: [KnowledgeConceptID: KnowledgeCollectionID] = [:]
        for collection in catalog.collections {
            for conceptID in collection.conceptIDs
            where memberships[conceptID] == nil {
                memberships[conceptID] = collection.id
            }
        }
        return memberships
    }

    private func latestRevisions(
        _ revisions: [PersonalConceptRevision],
        allowedConceptIDs: Set<KnowledgeConceptID>
    ) -> [KnowledgeConceptID: PersonalConceptRevision] {
        revisions.reduce(into: [:]) { result, revision in
            guard allowedConceptIDs.contains(revision.conceptID) else {
                return
            }
            guard let current = result[revision.conceptID] else {
                result[revision.conceptID] = revision
                return
            }
            if current.createdAt < revision.createdAt
                || (
                    current.createdAt == revision.createdAt
                        && current.id.rawValue < revision.id.rawValue
                )
            {
                result[revision.conceptID] = revision
            }
        }
    }

    private func deduplicatedRelations(
        _ relations: [PersonalKnowledgeRelation],
        allowedConceptIDs: Set<KnowledgeConceptID>
    ) -> [PersonalKnowledgeRelation] {
        var byID: [
            PersonalKnowledgeRelationID: PersonalKnowledgeRelation
        ] = [:]
        for relation in relations
        where allowedConceptIDs.contains(relation.sourceConceptID)
            && allowedConceptIDs.contains(relation.targetConceptID) {
            if let current = byID[relation.id],
               current.createdAt > relation.createdAt {
                continue
            }
            byID[relation.id] = relation
        }
        return byID.values.sorted {
            if $0.createdAt == $1.createdAt {
                return $0.id.rawValue < $1.id.rawValue
            }
            return $0.createdAt < $1.createdAt
        }
    }
}
