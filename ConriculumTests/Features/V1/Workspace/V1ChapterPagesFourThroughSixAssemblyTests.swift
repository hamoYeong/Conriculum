import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct V1ChapterPagesFourThroughSixAssemblyTests {
    private struct PageContract {
        let tags: [V1LearningSectionTag]
        let requiredActivityIDs: Set<LearningActivityID>
        let knowledgeConceptIDs: Set<KnowledgeConceptID>
        let promotionEvidenceIDs: Set<LearningActivityID>
    }

    private let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
    private let responseUUID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000106"
    )!

    @Test
    func pagesFourThroughSixMatchTheCompassCoreClosureContract() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let catalogIDs = Set(catalog.concepts.map(\.id))
        let contracts: [Int: PageContract] = [
            4: PageContract(
                tags: [
                    .learningCompass, .situation, .comparison, .definition,
                    .decisionCriteria, .codeExplanation, .knowledgeLink,
                    .matching, .codeAssembly, .choiceWithReason,
                    .learningClosure, .enrichmentTask,
                    .personalKnowledgePromotion,
                ],
                requiredActivityIDs: [
                    "activity-page04-compass",
                    "activity-page04-matching",
                    "activity-page04-code-assembly",
                    "activity-page04-choice",
                    "activity-page04-completion",
                ],
                knowledgeConceptIDs: ["concept-identifier-naming"],
                promotionEvidenceIDs: [
                    "activity-page04-code-assembly",
                    "activity-page04-choice",
                ]
            ),
            5: PageContract(
                tags: [
                    .learningCompass, .situation, .comparison, .definition,
                    .codeExplanation, .comparison, .knowledgeLink,
                    .codeAssembly, .cardSorting, .choiceWithReason,
                    .learningClosure, .enrichmentTask,
                    .personalKnowledgePromotion,
                ],
                requiredActivityIDs: [
                    "activity-page05-compass",
                    "activity-page05-code-assembly",
                    "activity-page05-card-sorting",
                    "activity-page05-choice",
                    "activity-page05-completion",
                ],
                knowledgeConceptIDs: [
                    "concept-constants-variables",
                    "concept-problem-boundary",
                ],
                promotionEvidenceIDs: [
                    "activity-page05-card-sorting",
                    "activity-page05-choice",
                ]
            ),
            6: PageContract(
                tags: [
                    .learningCompass, .situation, .comparison, .definition,
                    .comparison, .decisionCriteria, .knowledgeLink,
                    .matching, .fillInBlank, .choiceWithReason,
                    .learningClosure, .enrichmentTask,
                    .personalKnowledgePromotion,
                ],
                requiredActivityIDs: [
                    "activity-page06-compass",
                    "activity-page06-matching",
                    "activity-page06-fill-blank",
                    "activity-page06-choice",
                    "activity-page06-completion",
                ],
                knowledgeConceptIDs: [
                    "concept-type-inference-annotation",
                    "concept-literal",
                    "concept-identifier-naming",
                ],
                promotionEvidenceIDs: [
                    "activity-page06-matching",
                    "activity-page06-choice",
                ]
            ),
        ]

        for order in 4...6 {
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

            let closureSection = try #require(
                page.sections.first { $0.content.tag == .learningClosure }
            )
            let enrichmentSection = try #require(
                page.sections.first { $0.content.tag == .enrichmentTask }
            )
            let promotionSection = try #require(
                page.sections.first {
                    $0.content.tag == .personalKnowledgePromotion
                }
            )
            #expect(enrichmentSection.order > closureSection.order)
            #expect(promotionSection.order > closureSection.order)

            guard case let .personalKnowledgePromotion(promotion) =
                promotionSection.content
            else {
                Issue.record("개인 지식 후보 mapping이 올바르지 않다.")
                return
            }
            #expect(
                Set(promotion.evidenceActivityIDs)
                    == contract.promotionEvidenceIDs
            )
            #expect(promotion.evidenceActivityIDs.allSatisfy(activityIDs.contains))
            #expect(promotion.conceptIDs.allSatisfy(catalogIDs.contains))
        }
    }

    @Test
    func firstSixLessonsAreAssembled() throws {
        let chapter = try loadChapter()

        for page in chapter.progressPages.prefix(6) {
            #expect(V1LearningContentAssembly.isAssembled(page))
        }
    }

    @Test
    func pageSixFillInBlankDraftAutosaves() async throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let page = try #require(
            chapter.progressPages.first { $0.order == 6 }
        )
        let activityID: LearningActivityID = "activity-page06-fill-blank"
        let fields = [
            V1ActivityResponseField(
                key: V1LearningActivityFieldKey.blank("amountType"),
                values: ["Int"]
            ),
            V1ActivityResponseField(
                key: V1LearningActivityFieldKey.blank("memberType"),
                values: ["Bool"]
            ),
            V1ActivityResponseField(
                key: V1LearningActivityFieldKey.blank("nicknameType"),
                values: ["String"]
            ),
        ]
        let draft = V1ChapterLearningFeature.ActivityDraft(
            responseID: ActivityResponseID(
                rawValue: responseUUID.uuidString.lowercased()
            ),
            activityID: activityID,
            fields: fields
        )
        let clock = TestClock()
        var state = V1ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: page.id
        )
        state.chapter = chapter
        state.knowledgeCatalog = catalog
        let store = TestStore(initialState: state) {
            V1ChapterLearningFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.date.now = timestamp
            $0.uuid = .constant(responseUUID)
            $0.v1LearningRecordClient.saveResponse = { response in
                #expect(response.activityID == activityID)
                #expect(response.fields == fields)
            }
        }

        await store.send(.activityDraftChanged(
            activityID: activityID,
            fields: fields
        )) {
            $0.activityDrafts[activityID] = draft
            $0.activitySaveStates[activityID] = .pending
        }
        await clock.advance(by: .milliseconds(750))
        await store.receive(.activityAutosaveDelayElapsed(activityID)) {
            $0.activitySaveStates[activityID] = .saving
        }
        await store.receive(.activitySaveResponse(
            activityID: activityID,
            response: .saved(draft: draft, savedAt: timestamp)
        )) {
            $0.activitySaveStates[activityID] = .saved(timestamp)
        }
    }

    private func loadChapter() throws -> V1Chapter {
        try ContentResourceDecoder().decode(V1Chapter.self, from: .chapter02)
    }

    private func loadKnowledgeCatalog() throws -> KnowledgeCatalog {
        try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
    }
}
