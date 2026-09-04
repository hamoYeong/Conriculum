import Testing

@testable import Conriculum

@MainActor
struct ChapterPagesSevenAndEightAssemblyTests {
    private struct PageContract {
        let tags: [LearningSectionTag]
        let requiredActivityIDs: Set<LearningActivityID>
        let knowledgeConceptIDs: Set<KnowledgeConceptID>
    }

    @Test
    func pagesSevenThroughNineMatchStructureTransferAndChunkContracts() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let catalogIDs = Set(catalog.concepts.map(\.id))
        let contracts: [Int: PageContract] = [
            7: PageContract(
                tags: [
                    .learningCompass, .situation, .comparison, .definition,
                    .processGuide, .knowledgeLink, .cardSorting, .freeResponse,
                    .cardSorting, .learningClosure, .enrichmentTask,
                    .personalKnowledgePromotion, .personalKnowledgeRelation,
                ],
                requiredActivityIDs: [
                    "activity-page07-compass",
                    "activity-page07-role-sorting",
                    "activity-page07-free-response",
                    "activity-page07-boundary-sorting",
                    "activity-page07-completion",
                ],
                knowledgeConceptIDs: [
                    "concept-related-value-grouping",
                    "concept-input-rule-output",
                    "concept-identifier-naming",
                ]
            ),
            8: PageContract(
                tags: [
                    .learningCompass, .situation, .processGuide,
                    .codeExplanation, .knowledgeLink, .cardSorting,
                    .codeAssembly, .cardSorting, .freeResponse, .recallCheck,
                    .learningClosure, .enrichmentTask,
                    .personalKnowledgePromotion, .personalKnowledgeRelation,
                    .knowledgeChangeSummary,
                ],
                requiredActivityIDs: [
                    "activity-page08-compass",
                    "activity-page08-value-sorting",
                    "activity-page08-code-assembly",
                    "activity-page08-role-sorting",
                    "activity-page08-free-response",
                    "activity-page08-recall-check",
                    "activity-page08-completion",
                ],
                knowledgeConceptIDs: [
                    "concept-value",
                    "concept-type-selection",
                    "concept-identifier-naming",
                    "concept-constants-variables",
                    "concept-type-inference-annotation",
                    "concept-related-value-grouping",
                ]
            ),
            9: PageContract(
                tags: [
                    .learningCompass, .situation, .comparison,
                    .decisionCriteria, .knowledgeLink, .semanticChunkReading,
                    .freeResponse, .recallCheck, .learningClosure,
                    .enrichmentTask, .personalKnowledgePromotion,
                ],
                requiredActivityIDs: [
                    "activity-page09-compass",
                    "activity-page09-semantic-chunk",
                    "activity-page09-free-response",
                    "activity-page09-recall",
                    "activity-page09-closure",
                ],
                knowledgeConceptIDs: [
                    "concept-semantic-chunk-reading",
                    "concept-related-value-grouping",
                    "concept-input-rule-output",
                ]
            ),
        ]

        for order in 7...9 {
            let page = try #require(
                chapter.progressPages.first { $0.order == order }
            )
            let contract = try #require(contracts[order])
            let activityIDs = Set(page.activities.map(\.id))

            #expect(page.sections.map(\.content.tag) == contract.tags)
            #expect(
                Set(page.activities.filter(\.isRequired).map(\.id))
                    == contract.requiredActivityIDs
            )
            #expect(
                Set(page.knowledgeLinks.map(\.conceptID))
                    == contract.knowledgeConceptIDs
            )
            #expect(page.knowledgeLinks.filter { $0.role == .primary }.count == 1)
            #expect(page.knowledgeContext.currentlyUsedConceptIDs.count <= 3)
            #expect(page.knowledgeLinks.allSatisfy {
                catalogIDs.contains($0.conceptID)
            })
            #expect(page.sections.compactMap(\.activityID).allSatisfy(
                activityIDs.contains
            ))

            let closureOrder = try #require(
                page.sections.first { $0.content.tag == .learningClosure }?.order
            )
            let optionalTags: Set<LearningSectionTag> = [
                .enrichmentTask,
                .personalKnowledgePromotion,
                .personalKnowledgeRelation,
                .knowledgeChangeSummary,
            ]
            #expect(page.sections.allSatisfy {
                optionalTags.contains($0.content.tag) == false
                    || $0.order > closureOrder
            })
        }
    }

    @Test
    func pageNineRequiresNonContiguousSemanticChunkEvidence() throws {
        let chapter = try loadChapter()
        let page = try #require(
            chapter.progressPages.first { $0.order == 9 }
        )
        let section = try #require(
            page.sections.first { $0.content.tag == .semanticChunkReading }
        )
        guard case let .semanticChunkReading(content) = section.content else {
            Issue.record("9페이지 핵심 활동이 의미 단위 조각 읽기가 아니다.")
            return
        }

        #expect(content.elements.count == 7)
        #expect(content.selectionPrompt.contains("떨어진"))
        #expect(content.chunkNamePrompt.contains("행동"))
        #expect(content.flowPrompt.contains("다음"))
        #expect(content.changePrompt.contains("달라지는지"))
        #expect(content.completionEvidence.count == 5)
        #expect(section.activityID == "activity-page09-semantic-chunk")
    }

    @Test
    func pageNineUsesTheNewKnowledgeConceptAndRoutesToChapterThree() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let page = try #require(
            chapter.progressPages.first { $0.order == 9 }
        )
        let concept = try #require(
            catalog.concepts.first {
                $0.id == "concept-semantic-chunk-reading"
            }
        )

        #expect(concept.title == "코드를 의미 단위 조각으로 읽기")
        #expect(concept.judgmentQuestions.count == 5)
        #expect(page.navigation.previous?.pageID == "chapter-02-page-08")
        #expect(page.navigation.next?.pageID == "chapter-03-page-01")
        #expect(page.navigation.next?.label == "값으로 새로운 값을 계산하기")
        #expect(LearningContentAssembly.isAssembled(page))
    }

    private func loadChapter() throws -> Chapter {
        try ContentResourceDecoder().decode(Chapter.self, from: .chapter02)
    }

    private func loadKnowledgeCatalog() throws -> KnowledgeCatalog {
        try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
    }
}
