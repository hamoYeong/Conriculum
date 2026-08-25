import Foundation
import Testing

@testable import Conriculum

@MainActor
struct KnowledgeContextSnapshotComposerTests {
    @Test
    func everyPageComposesItsExactDirectAndNearbyScope() throws {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let contracts: [
            LearningPageID: (
                direct: [KnowledgeConceptID],
                nearby: [KnowledgeConceptID]
            )
        ] = [
            "chapter-02-overview": (
                [
                    "concept-value",
                    "concept-type-selection",
                    "concept-identifier-naming",
                ],
                ["concept-expressions-operations", "concept-type-modeling"]
            ),
            "chapter-02-page-01": (
                [
                    "concept-value",
                    "concept-literal",
                    "concept-concrete-values-rules",
                ],
                ["concept-type"]
            ),
            "chapter-02-page-02": (
                [
                    "concept-type",
                    "concept-string",
                    "concept-int",
                    "concept-double",
                    "concept-bool",
                ],
                ["concept-type-selection"]
            ),
            "chapter-02-page-03": (
                [
                    "concept-type-selection",
                    "concept-string",
                    "concept-int",
                    "concept-double",
                    "concept-bool",
                ],
                ["concept-identifier-naming"]
            ),
            "chapter-02-page-04": (
                ["concept-identifier-naming"],
                ["concept-value", "concept-constants-variables"]
            ),
            "chapter-02-page-05": (
                ["concept-constants-variables", "concept-problem-boundary"],
                ["concept-identifier-naming"]
            ),
            "chapter-02-page-06": (
                [
                    "concept-type-inference-annotation",
                    "concept-literal",
                    "concept-identifier-naming",
                ],
                ["concept-type-selection", "concept-identifier-naming"]
            ),
            "chapter-02-page-07": (
                [
                    "concept-related-value-grouping",
                    "concept-input-rule-output",
                    "concept-identifier-naming",
                ],
                ["concept-type-modeling", "concept-identifier-naming"]
            ),
            "chapter-02-page-08": (
                [
                    "concept-value",
                    "concept-type-selection",
                    "concept-identifier-naming",
                    "concept-constants-variables",
                    "concept-type-inference-annotation",
                    "concept-related-value-grouping",
                ],
                ["concept-expressions-operations", "concept-type-modeling"]
            ),
        ]

        for page in chapter.allPages {
            let contract = try #require(contracts[page.id])
            let snapshot = try KnowledgeContextSnapshotComposer().compose(
                chapter: chapter,
                catalog: catalog,
                pageID: page.id,
                revisions: []
            )

            #expect(snapshot.pageTitle == page.title)
            #expect(snapshot.directConcepts.map(\.id) == contract.direct)
            #expect(snapshot.nearbyConcepts.map(\.id) == contract.nearby)
            #expect(snapshot.changedConcepts.isEmpty)
            #expect(snapshot.directConcepts.allSatisfy {
                $0.personalRevision == nil
            })
            #expect(snapshot.nearbyConcepts.allSatisfy {
                $0.nearbyReason?.isEmpty == false
            })
        }
    }

    @Test
    func latestRevisionOverlaysBaseWithoutReplacingIt() throws {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let pageID: LearningPageID = "chapter-02-page-05"
        let oldRevision = revision(
            id: "revision-constants-old",
            conceptID: "concept-constants-variables",
            personalTitle: "예전 이름",
            explanation: "예전 설명",
            evidenceActivityID: "activity-page05-card-sorting",
            timestamp: 100
        )
        let latestRevision = revision(
            id: "revision-constants-latest",
            conceptID: "concept-constants-variables",
            personalTitle: "변경 책임 약속",
            explanation: "현재 책임 안에서 재할당할지를 기준으로 고른다.",
            evidenceActivityID: "activity-page05-choice",
            timestamp: 200
        )
        let nearbyRevision = revision(
            id: "revision-naming-latest",
            conceptID: "concept-identifier-naming",
            personalTitle: "역할 이름",
            explanation: "이름은 값이 맡는 역할을 드러낸다.",
            evidenceActivityID: "activity-page04-choice",
            timestamp: 300
        )

        let snapshot = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: pageID,
            revisions: [oldRevision, latestRevision, nearbyRevision]
        )

        let constants = try #require(
            snapshot.directConcepts.first {
                $0.id == "concept-constants-variables"
            }
        )
        #expect(constants.concept.title == "상수와 변수")
        #expect(constants.personalRevision == latestRevision)
        #expect(constants.role == .primary)
        #expect(constants.isChangedInChapter)
        #expect(snapshot.changedConcepts.map(\.id) == [
            "concept-identifier-naming",
            "concept-constants-variables",
        ])

        let nearby = try #require(snapshot.nearbyConcepts.first)
        #expect(nearby.id == "concept-identifier-naming")
        #expect(nearby.personalRevision == nearbyRevision)
        #expect(nearby.nearbyReason?.isEmpty == false)
    }

    @Test
    func revisionEvidenceUsesThePageContractThenFallsBackToStoredEvidence()
        throws
    {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let namingRevision = revision(
            id: "revision-naming-evidence",
            conceptID: "concept-identifier-naming",
            personalTitle: "역할 이름",
            explanation: "이름은 값이 맡는 역할을 드러낸다.",
            evidenceActivityID: "activity-page04-choice",
            timestamp: 100
        )

        let pageFive = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: "chapter-02-page-05",
            revisions: [namingRevision]
        )
        let constants = try #require(pageFive.directConcepts.first {
            $0.id == "concept-constants-variables"
        })
        #expect(
            constants.revisionEvidenceActivityID
                == "activity-page05-card-sorting"
        )
        let nearbyNaming = try #require(pageFive.nearbyConcepts.first {
            $0.id == "concept-identifier-naming"
        })
        #expect(
            nearbyNaming.revisionEvidenceActivityID
                == namingRevision.evidenceActivityID
        )

        let overview = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: chapter.overview.id,
            revisions: []
        )
        #expect(overview.directConcepts.allSatisfy {
            $0.revisionEvidenceActivityID == nil
        })
    }

    @Test
    func relationContractAndLatestPersonalRelationsRemainSeparateFromCatalog()
        throws
    {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()
        let oldRelation = relation(
            id: "personal-relation-grouping-modeling",
            statement: "예전 관계 문장",
            timestamp: 100
        )
        let latestRelation = relation(
            id: oldRelation.id,
            statement: "값 묶기의 경계는 타입 책임으로 이어진다.",
            timestamp: 200
        )

        let pageSeven = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: "chapter-02-page-07",
            revisions: [],
            relations: [oldRelation, latestRelation, latestRelation]
        )
        let contract = try #require(pageSeven.relationCreationContract)
        #expect(contract.sourceConceptIDs == [
            "concept-related-value-grouping"
        ])
        #expect(contract.targetConceptIDs == [
            "concept-type-modeling",
            "concept-identifier-naming",
        ])
        #expect(
            contract.evidenceActivityID == "activity-page07-role-sorting"
        )
        #expect(pageSeven.personalRelations == [latestRelation])
        #expect(pageSeven.baseRelations == catalog.relations)
        #expect(pageSeven.availableConcepts.count == catalog.concepts.count)

        let pageEight = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: "chapter-02-page-08",
            revisions: [],
            relations: []
        )
        let pageEightContract = try #require(
            pageEight.relationCreationContract
        )
        #expect(pageEightContract.sourceConceptIDs == [
            "concept-value",
            "concept-type-selection",
            "concept-identifier-naming",
            "concept-constants-variables",
            "concept-type-inference-annotation",
            "concept-related-value-grouping",
        ])
        #expect(pageEightContract.targetConceptIDs.suffix(2) == [
            "concept-expressions-operations",
            "concept-type-modeling",
        ])
        #expect(
            pageEightContract.evidenceActivityID
                == "activity-page08-value-sorting"
        )

        let pageSix = try KnowledgeContextSnapshotComposer().compose(
            chapter: chapter,
            catalog: catalog,
            pageID: "chapter-02-page-06",
            revisions: [],
            relations: []
        )
        #expect(pageSix.relationCreationContract == nil)
    }

    @Test
    func missingPageAndConceptReportStableIdentifiers() throws {
        let chapter = try loadChapter()
        let catalog = try loadCatalog()

        #expect(throws: KnowledgeContextSnapshotComposerError.missingPage(
            "missing-page"
        )) {
            try KnowledgeContextSnapshotComposer().compose(
                chapter: chapter,
                catalog: catalog,
                pageID: "missing-page",
                revisions: []
            )
        }

        let missingConceptPage = LearningPage(
            id: "test-page",
            kind: .lesson,
            order: 1,
            title: "테스트",
            goal: "누락 개념을 검증한다.",
            sections: [],
            activities: [],
            knowledgeLinks: [
                LearningKnowledgeLink(
                    conceptID: "missing-concept",
                    role: .primary,
                    usage: "테스트",
                    displayTiming: nil
                )
            ],
            knowledgeContext: PageKnowledgeContext(
                currentlyUsedConceptIDs: ["missing-concept"],
                currentlyUsedSummary: "테스트",
                changedKnowledgeSummary: "테스트",
                nearbyKnowledge: [],
                refreshTriggers: ["테스트"],
                emptyStateMessage: "없음",
                focusModeSummary: "테스트"
            ),
            navigation: LearningPageNavigation(previous: nil, next: nil)
        )
        let invalidChapter = Chapter(
            id: chapter.id,
            stageID: chapter.stageID,
            order: chapter.order,
            title: chapter.title,
            summary: chapter.summary,
            overview: chapter.overview,
            pages: [missingConceptPage]
        )

        #expect(throws: KnowledgeContextSnapshotComposerError.missingConcept(
            "missing-concept"
        )) {
            try KnowledgeContextSnapshotComposer().compose(
                chapter: invalidChapter,
                catalog: catalog,
                pageID: missingConceptPage.id,
                revisions: []
            )
        }
    }

    private func revision(
        id: PersonalConceptRevisionID,
        conceptID: KnowledgeConceptID,
        personalTitle: String,
        explanation: String,
        evidenceActivityID: LearningActivityID,
        timestamp: TimeInterval
    ) -> PersonalConceptRevision {
        PersonalConceptRevision(
            id: id,
            conceptID: conceptID,
            personalTitle: personalTitle,
            explanation: explanation,
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: evidenceActivityID,
            createdAt: Date(timeIntervalSince1970: timestamp)
        )
    }

    private func relation(
        id: PersonalKnowledgeRelationID,
        statement: String,
        timestamp: TimeInterval
    ) -> PersonalKnowledgeRelation {
        PersonalKnowledgeRelation(
            id: id,
            sourceConceptID: "concept-related-value-grouping",
            targetConceptID: "concept-type-modeling",
            statement: statement,
            reason: "관련 값의 책임을 구조로 보존하기 때문이다.",
            evidenceActivityID: "activity-page07-role-sorting",
            createdAt: Date(timeIntervalSince1970: timestamp)
        )
    }

    private func loadChapter() throws -> Chapter {
        try ContentResourceDecoder().decode(Chapter.self, from: .chapter02)
    }

    private func loadCatalog() throws -> KnowledgeCatalog {
        try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
    }
}
