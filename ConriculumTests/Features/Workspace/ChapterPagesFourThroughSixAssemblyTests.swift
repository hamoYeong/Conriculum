import AppKit
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct ChapterPagesFourThroughSixAssemblyTests {
    private struct PageContract {
        let tags: [LearningSectionTag]
        let requiredActivityIDs: Set<LearningActivityID>
        let knowledgeConceptIDs: Set<KnowledgeConceptID>
        let promotionEvidenceIDs: Set<LearningActivityID>
        let promotionConceptIDs: Set<KnowledgeConceptID>
    }

    private let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
    private let responseUUID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000106"
    )!

    @Test
    func pagesFourThroughSixMatchTheirComponentAndEvidenceContracts() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let catalogIDs = Set(catalog.concepts.map(\.id))
        let contracts: [Int: PageContract] = [
            4: PageContract(
                tags: [
                    .situation, .comparison, .definition, .decisionCriteria,
                    .codeExplanation, .knowledgeLink,
                    .learningStateSelection, .matching, .codeAssembly,
                    .choiceWithReason, .personalExpressionComparison,
                    .personalKnowledgePromotion, .enrichmentTask,
                    .completionCheck,
                ],
                requiredActivityIDs: [
                    "activity-page04-matching",
                    "activity-page04-code-assembly",
                    "activity-page04-choice",
                    "activity-page04-completion",
                ],
                knowledgeConceptIDs: ["concept-identifier-naming"],
                promotionEvidenceIDs: [
                    "activity-page04-code-assembly",
                    "activity-page04-choice",
                ],
                promotionConceptIDs: ["concept-identifier-naming"]
            ),
            5: PageContract(
                tags: [
                    .knowledgeRecall, .situation, .comparison, .definition,
                    .codeExplanation, .comparison, .knowledgeLink,
                    .learningStateSelection, .codeAssembly, .cardSorting,
                    .choiceWithReason, .personalExpressionComparison,
                    .personalKnowledgePromotion, .enrichmentTask,
                    .completionCheck,
                ],
                requiredActivityIDs: [
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
                ],
                promotionConceptIDs: [
                    "concept-constants-variables",
                    "concept-problem-boundary",
                ]
            ),
            6: PageContract(
                tags: [
                    .situation, .comparison, .definition, .comparison,
                    .decisionCriteria, .knowledgeLink,
                    .learningStateSelection, .matching, .fillInBlank,
                    .choiceWithReason, .personalExpressionComparison,
                    .personalKnowledgePromotion, .enrichmentTask,
                    .completionCheck,
                ],
                requiredActivityIDs: [
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
                ],
                promotionConceptIDs: [
                    "concept-type-inference-annotation"
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
            #expect(page.knowledgeLinks.allSatisfy {
                catalogIDs.contains($0.conceptID)
            })
            #expect(page.knowledgeContext.currentlyUsedConceptIDs.allSatisfy {
                catalogIDs.contains($0)
            })
            #expect(page.knowledgeContext.nearbyKnowledge.allSatisfy {
                catalogIDs.contains($0.conceptID)
            })
            #expect(page.sections.compactMap(\.activityID).allSatisfy {
                activityIDs.contains($0)
            })
            #expect(page.activities.allSatisfy { activity in
                page.sections.contains { $0.id == activity.sectionID }
            })

            try validatePersonalization(
                in: page,
                contract: contract,
                activityIDs: activityIDs,
                catalogIDs: catalogIDs
            )
        }
    }

    @Test
    func firstSixLessonsAreAssembled() throws {
        let chapter = try loadChapter()

        for page in chapter.progressPages.prefix(6) {
            #expect(Chapter02ContentAssembly.isAssembled(page))
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
            ActivityResponseField(
                key: LearningActivityFieldKey.blank("amountType"),
                values: ["Int"]
            ),
            ActivityResponseField(
                key: LearningActivityFieldKey.blank("memberType"),
                values: ["Bool"]
            ),
            ActivityResponseField(
                key: LearningActivityFieldKey.blank("nicknameType"),
                values: ["String"]
            ),
        ]
        let draft = ChapterLearningFeature.ActivityDraft(
            responseID: ActivityResponseID(
                rawValue: responseUUID.uuidString.lowercased()
            ),
            activityID: activityID,
            fields: fields
        )
        let clock = TestClock()
        var state = ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: page.id
        )
        state.chapter = chapter
        state.knowledgeCatalog = catalog
        let store = TestStore(initialState: state) {
            ChapterLearningFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.date.now = timestamp
            $0.uuid = .constant(responseUUID)
            $0.learningRecordClient.saveResponse = { response in
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

    @Test
    func pagesFourThroughSixRenderThroughTheSharedTree() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()

        for page in chapter.progressPages.dropFirst(3).prefix(3) {
            var state = ChapterLearningFeature.State(
                chapterID: chapter.id,
                currentPageID: page.id
            )
            state.chapter = chapter
            state.knowledgeCatalog = catalog
            let view = ChapterLearningView(
                store: Store(initialState: state) {
                    ChapterLearningFeature()
                }
            )
            .frame(width: 760, height: 900)
            let hostingView = NSHostingView(rootView: view)
            hostingView.frame = NSRect(
                x: 0,
                y: 0,
                width: 760,
                height: 900
            )
            hostingView.layoutSubtreeIfNeeded()
            let image = try #require(
                hostingView.bitmapImageRepForCachingDisplay(
                    in: hostingView.bounds
                )
            )
            hostingView.cacheDisplay(in: hostingView.bounds, to: image)

            #expect(image.size == NSSize(width: 760, height: 900))
            #expect(sampledColorCount(in: image) > 3)
        }
    }

    private func validatePersonalization(
        in page: LearningPage,
        contract: PageContract,
        activityIDs: Set<LearningActivityID>,
        catalogIDs: Set<KnowledgeConceptID>
    ) throws {
        let stateSection = try #require(
            page.sections.first {
                $0.content.tag == .learningStateSelection
            }
        )
        guard case let .learningStateSelection(stateSelection) =
            stateSection.content
        else {
            Issue.record("학습 상태 section mapping이 올바르지 않다.")
            return
        }
        let stateIDs = Set(stateSelection.options.map(\.id))

        let enrichmentSection = try #require(
            page.sections.first { $0.content.tag == .enrichmentTask }
        )
        guard case let .enrichmentTask(enrichment) = enrichmentSection.content
        else {
            Issue.record("확장·심화 section mapping이 올바르지 않다.")
            return
        }
        #expect(stateIDs.contains(enrichment.requiredStateID))
        #expect(enrichment.conceptIDs.allSatisfy(catalogIDs.contains))

        let promotionSection = try #require(
            page.sections.first {
                $0.content.tag == .personalKnowledgePromotion
            }
        )
        guard case let .personalKnowledgePromotion(promotion) =
            promotionSection.content
        else {
            Issue.record("개인 지식 후보 section mapping이 올바르지 않다.")
            return
        }
        #expect(promotion.candidateKind == .conceptRevision)
        #expect(
            Set(promotion.evidenceActivityIDs)
                == contract.promotionEvidenceIDs
        )
        #expect(Set(promotion.conceptIDs) == contract.promotionConceptIDs)
        #expect(promotion.evidenceActivityIDs.allSatisfy(activityIDs.contains))
        #expect(promotion.conceptIDs.allSatisfy(catalogIDs.contains))

        let completionSection = try #require(
            page.sections.first { $0.content.tag == .completionCheck }
        )
        let completionActivityID = try #require(completionSection.activityID)
        #expect(
            page.activities.first { $0.id == completionActivityID }?
                .isRequired == true
        )
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

    private func sampledColorCount(
        in image: NSBitmapImageRep
    ) -> Int {
        let horizontalStep = max(image.pixelsWide / 24, 1)
        let verticalStep = max(image.pixelsHigh / 24, 1)
        var colors: Set<Int> = []

        for x in stride(from: 0, to: image.pixelsWide, by: horizontalStep) {
            for y in stride(from: 0, to: image.pixelsHigh, by: verticalStep) {
                guard let color = image.colorAt(x: x, y: y)?
                    .usingColorSpace(.deviceRGB)
                else { continue }

                let red = Int(color.redComponent * 15)
                let green = Int(color.greenComponent * 15)
                let blue = Int(color.blueComponent * 15)
                colors.insert((red << 8) | (green << 4) | blue)
            }
        }

        return colors.count
    }
}
