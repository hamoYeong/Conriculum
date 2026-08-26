import Foundation
import Testing

@testable import Conriculum

@MainActor
struct KnowledgeSystemSnapshotComposerTests {
    @Test
    func catalogOrderLatestRevisionAndUniqueRelationsArePreserved()
        throws
    {
        let catalog = try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let oldRevision = revision(
            id: "revision-old",
            conceptID: "concept-type",
            explanation: "이전 설명",
            timestamp: 10
        )
        let latestRevision = revision(
            id: "revision-latest",
            conceptID: "concept-type",
            explanation: "최신 설명",
            timestamp: 20
        )
        let relation = personalRelation(
            id: "personal-relation-value-type",
            source: "concept-value",
            target: "concept-type",
            timestamp: 30
        )

        let snapshot = KnowledgeSystemSnapshotComposer().compose(
            catalog: catalog,
            revisions: [latestRevision, oldRevision],
            personalRelations: [relation, relation]
        )

        #expect(snapshot.collections.map(\.id) == catalog.collections.map(\.id))
        #expect(snapshot.concepts.map(\.id) == catalog.concepts.map(\.id))
        #expect(
            snapshot.conceptItem(id: "concept-type")?.latestRevision
                == latestRevision
        )
        #expect(snapshot.personalRelations == [relation])
        #expect(
            snapshot.relatedConceptIDs(for: "concept-value")
                .contains("concept-type")
        )
    }

    @Test
    func danglingPersonalValuesAreExcludedFromTheSnapshot() throws {
        let catalog = try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let danglingRevision = revision(
            id: "revision-dangling",
            conceptID: "concept-missing",
            explanation: "연결할 수 없는 설명",
            timestamp: 10
        )
        let danglingRelation = personalRelation(
            id: "relation-dangling",
            source: "concept-value",
            target: "concept-missing",
            timestamp: 20
        )

        let snapshot = KnowledgeSystemSnapshotComposer().compose(
            catalog: catalog,
            revisions: [danglingRevision],
            personalRelations: [danglingRelation]
        )

        #expect(snapshot.personalRelations.isEmpty)
        #expect(snapshot.concepts.allSatisfy { $0.latestRevision == nil })
    }

    private func revision(
        id: PersonalConceptRevisionID,
        conceptID: KnowledgeConceptID,
        explanation: String,
        timestamp: TimeInterval
    ) -> PersonalConceptRevision {
        PersonalConceptRevision(
            id: id,
            conceptID: conceptID,
            personalTitle: nil,
            explanation: explanation,
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: "activity-evidence",
            createdAt: Date(timeIntervalSince1970: timestamp)
        )
    }

    private func personalRelation(
        id: PersonalKnowledgeRelationID,
        source: KnowledgeConceptID,
        target: KnowledgeConceptID,
        timestamp: TimeInterval
    ) -> PersonalKnowledgeRelation {
        PersonalKnowledgeRelation(
            id: id,
            sourceConceptID: source,
            targetConceptID: target,
            statement: "두 개념은 함께 판단한다.",
            reason: "테스트 관계",
            evidenceActivityID: "activity-evidence",
            createdAt: Date(timeIntervalSince1970: timestamp)
        )
    }
}
