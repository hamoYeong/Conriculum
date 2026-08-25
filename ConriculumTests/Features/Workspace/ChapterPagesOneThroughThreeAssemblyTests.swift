import AppKit
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct ChapterPagesOneThroughThreeAssemblyTests {
    private struct PageContract {
        let tags: [LearningSectionTag]
        let requiredActivityIDs: Set<LearningActivityID>
        let knowledgeConceptIDs: Set<KnowledgeConceptID>
    }

    private let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
    private let responseUUID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000103"
    )!

    @Test
    func pagesOneThroughThreeMatchTheirActivityAndKnowledgeContracts() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let catalogIDs = Set(catalog.concepts.map(\.id))
        let contracts: [Int: PageContract] = [
            1: PageContract(
                tags: [
                    .knowledgeRecall, .situation, .comparison, .definition,
                    .definition, .codeExplanation, .knowledgeLink,
                    .learningStateSelection, .cardSorting, .matching,
                    .choiceWithReason, .personalExpressionComparison,
                    .personalKnowledgePromotion, .enrichmentTask,
                    .completionCheck,
                ],
                requiredActivityIDs: [
                    "activity-page01-card-sorting",
                    "activity-page01-matching",
                    "activity-page01-choice",
                    "activity-page01-completion",
                ],
                knowledgeConceptIDs: [
                    "concept-value",
                    "concept-literal",
                    "concept-concrete-values-rules",
                ]
            ),
            2: PageContract(
                tags: [
                    .knowledgeRecall, .situation, .comparison, .definition,
                    .decisionCriteria, .knowledgeLink,
                    .learningStateSelection, .cardSorting, .matching,
                    .choiceWithReason, .personalExpressionComparison,
                    .personalKnowledgePromotion, .enrichmentTask,
                    .completionCheck,
                ],
                requiredActivityIDs: [
                    "activity-page02-card-sorting",
                    "activity-page02-matching",
                    "activity-page02-choice",
                    "activity-page02-completion",
                ],
                knowledgeConceptIDs: [
                    "concept-type",
                    "concept-string",
                    "concept-int",
                    "concept-double",
                    "concept-bool",
                ]
            ),
            3: PageContract(
                tags: [
                    .knowledgeRecall, .situation, .comparison,
                    .decisionCriteria, .definition, .knowledgeLink,
                    .learningStateSelection, .choiceWithReason,
                    .cardSorting, .freeResponse,
                    .personalExpressionComparison,
                    .personalKnowledgePromotion, .enrichmentTask,
                    .completionCheck,
                ],
                requiredActivityIDs: [
                    "activity-page03-choice",
                    "activity-page03-card-sorting",
                    "activity-page03-free-response",
                    "activity-page03-completion",
                ],
                knowledgeConceptIDs: [
                    "concept-type-selection",
                    "concept-string",
                    "concept-int",
                    "concept-double",
                    "concept-bool",
                ]
            ),
        ]

        for order in 1...3 {
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
                activityIDs: activityIDs,
                catalogIDs: catalogIDs
            )
        }
    }

    @Test
    func firstThreeLessonsRemainAssembled() throws {
        let chapter = try loadChapter()

        for page in chapter.progressPages.prefix(3) {
            #expect(Chapter02ContentAssembly.isAssembled(page))
        }
    }

    @Test
    func completionSelectionFlowsIntoTheAutosaveDraft() async throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let page = try #require(
            chapter.progressPages.first { $0.order == 1 }
        )
        let completionSection = try #require(
            page.sections.first { $0.content.tag == .completionCheck }
        )
        let activityID = try #require(completionSection.activityID)
        let fields = [
            ActivityResponseField(
                key: LearningActivityFieldKey.completionAssessment,
                values: [CompletionSelfAssessment.ready.rawValue]
            )
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
            $0.learningRecordClient.saveResponse = { _ in }
        }

        await store.send(.component(.completionAssessmentChanged(
            activityID: activityID,
            assessment: .ready
        ))) {
            $0.component.completionAssessments[activityID] = .ready
        }
        await store.receive(.component(.delegate(.activityFieldsChanged(
            activityID: activityID,
            fields: fields
        ))))
        await store.receive(.activityDraftChanged(
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
    func pagesOneThroughThreeRenderThroughTheSharedTree() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()

        for page in chapter.progressPages.prefix(3) {
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
        activityIDs: Set<LearningActivityID>,
        catalogIDs: Set<KnowledgeConceptID>
    ) throws {
        let comparisonSection = try #require(
            page.sections.first {
                $0.content.tag == .personalExpressionComparison
            }
        )
        guard case let .personalExpressionComparison(comparison) =
            comparisonSection.content
        else {
            Issue.record("나의 표현 비교 section mapping이 올바르지 않다.")
            return
        }
        #expect(comparison.conceptIDs.allSatisfy(catalogIDs.contains))

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
        #expect(!promotion.evidenceActivityIDs.isEmpty)
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
