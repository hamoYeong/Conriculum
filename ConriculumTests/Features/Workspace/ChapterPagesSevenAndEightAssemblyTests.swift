import AppKit
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct ChapterPagesSevenAndEightAssemblyTests {
    private struct PageContract {
        let tags: [LearningSectionTag]
        let requiredActivityIDs: Set<LearningActivityID>
        let knowledgeConceptIDs: Set<KnowledgeConceptID>
        let promotionEvidenceIDs: Set<LearningActivityID>
        let promotionConceptIDs: Set<KnowledgeConceptID>
        let relationSourceIDs: Set<KnowledgeConceptID>
        let relationTargetIDs: Set<KnowledgeConceptID>
        let relationEvidenceIDs: Set<LearningActivityID>
    }

    private let timestamp = Date(timeIntervalSince1970: 1_725_782_400)

    @Test
    func pagesSevenAndEightMatchTheirComponentContracts() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let catalogIDs = Set(catalog.concepts.map(\.id))
        let chapterConceptIDs: Set<KnowledgeConceptID> = [
            "concept-value",
            "concept-type-selection",
            "concept-identifier-naming",
            "concept-constants-variables",
            "concept-type-inference-annotation",
            "concept-related-value-grouping",
        ]
        let contracts: [Int: PageContract] = [
            7: PageContract(
                tags: [
                    .knowledgeRecall, .situation, .comparison, .definition,
                    .processGuide, .knowledgeLink, .learningStateSelection,
                    .cardSorting, .freeResponse, .cardSorting,
                    .personalExpressionComparison,
                    .personalKnowledgePromotion,
                    .personalKnowledgeRelation, .enrichmentTask,
                    .completionCheck,
                ],
                requiredActivityIDs: [
                    "activity-page07-role-sorting",
                    "activity-page07-free-response",
                    "activity-page07-boundary-sorting",
                    "activity-page07-completion",
                ],
                knowledgeConceptIDs: [
                    "concept-related-value-grouping",
                    "concept-input-rule-output",
                    "concept-identifier-naming",
                ],
                promotionEvidenceIDs: [
                    "activity-page07-free-response",
                    "activity-page07-boundary-sorting",
                ],
                promotionConceptIDs: ["concept-related-value-grouping"],
                relationSourceIDs: ["concept-related-value-grouping"],
                relationTargetIDs: [
                    "concept-type-modeling",
                    "concept-identifier-naming",
                ],
                relationEvidenceIDs: [
                    "activity-page07-role-sorting",
                    "activity-page07-free-response",
                    "activity-page07-boundary-sorting",
                ]
            ),
            8: PageContract(
                tags: [
                    .situation, .processGuide, .knowledgeRecall,
                    .codeExplanation, .knowledgeLink,
                    .learningStateSelection, .cardSorting, .codeAssembly,
                    .cardSorting, .freeResponse, .enrichmentTask,
                    .recallCheck, .personalExpressionComparison,
                    .personalKnowledgePromotion,
                    .personalKnowledgeRelation, .knowledgeChangeSummary,
                    .completionCheck,
                ],
                requiredActivityIDs: [
                    "activity-page08-value-sorting",
                    "activity-page08-code-assembly",
                    "activity-page08-role-sorting",
                    "activity-page08-free-response",
                    "activity-page08-recall-check",
                    "activity-page08-completion",
                ],
                knowledgeConceptIDs: chapterConceptIDs,
                promotionEvidenceIDs: [
                    "activity-page08-free-response",
                    "activity-page08-recall-check",
                ],
                promotionConceptIDs: chapterConceptIDs,
                relationSourceIDs: chapterConceptIDs,
                relationTargetIDs: chapterConceptIDs.union([
                    "concept-expressions-operations",
                    "concept-type-modeling",
                ]),
                relationEvidenceIDs: [
                    "activity-page08-value-sorting",
                    "activity-page08-code-assembly",
                    "activity-page08-role-sorting",
                ]
            ),
        ]

        for order in 7...8 {
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
    func allEightLessonsAreAssembled() throws {
        let chapter = try loadChapter()

        #expect(chapter.progressPages.count == 8)
        #expect(chapter.progressPages.allSatisfy(
            Chapter02ContentAssembly.isAssembled
        ))
    }

    @Test
    func pageEightSeparatesConfirmedChangesFromPendingCandidates() throws {
        let chapter = try loadChapter()
        let page = try #require(
            chapter.progressPages.first { $0.order == 8 }
        )
        let summarySection = try #require(
            page.sections.first { $0.content.tag == .knowledgeChangeSummary }
        )
        guard case let .knowledgeChangeSummary(summary) =
            summarySection.content
        else {
            Issue.record("지식 변화 요약 section mapping이 올바르지 않다.")
            return
        }

        #expect(!summary.confirmedExpressions.isEmpty)
        #expect(!summary.confirmedRelations.isEmpty)
        #expect(!summary.pendingCandidates.isEmpty)
        #expect(summary.confirmedExpressions != summary.pendingCandidates)
        #expect(summary.confirmedRelations != summary.pendingCandidates)
        #expect(!summary.nextUseSuggestion.isEmpty)
        #expect(!summary.emptyState.isEmpty)
    }

    @Test
    func pageEightNextActionShowsTheChapterTwoCompletionSummary() async throws {
        let chapter = try loadChapter()
        let page = try #require(
            chapter.progressPages.first { $0.order == 8 }
        )
        let expectedProgress = LearningProgress(
            chapterID: chapter.id,
            currentPageID: page.id,
            completedPageIDs: [],
            updatedAt: timestamp
        )
        var state = ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: page.id
        )
        state.chapter = chapter
        let store = TestStore(initialState: state) {
            ChapterLearningFeature()
        } withDependencies: {
            $0.date.now = timestamp
            $0.learningRecordClient.saveProgress = { progress in
                #expect(progress == expectedProgress)
            }
        }

        #expect(store.state.isLastPage)
        await store.send(.nextButtonTapped) {
            $0.isSavingNavigation = true
        }
        await store.receive(.navigationResponse(.saved(
            destination: .completionSummary,
            progress: expectedProgress,
            drafts: [],
            responses: []
        ))) {
            $0.isSavingNavigation = false
            $0.isShowingCompletionSummary = true
        }
    }

    @Test
    func pagesSevenAndEightRenderThroughTheSharedTree() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()

        for page in chapter.progressPages.suffix(2) {
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
        let promotionActivityID = try #require(promotionSection.activityID)
        #expect(
            page.activities.first { $0.id == promotionActivityID }?
                .isRequired == false
        )

        let relationSection = try #require(
            page.sections.first {
                $0.content.tag == .personalKnowledgeRelation
            }
        )
        guard case let .personalKnowledgeRelation(relation) =
            relationSection.content
        else {
            Issue.record("개인 지식 관계 section mapping이 올바르지 않다.")
            return
        }
        #expect(Set(relation.sourceConceptIDs) == contract.relationSourceIDs)
        #expect(Set(relation.targetConceptIDs) == contract.relationTargetIDs)
        #expect(
            Set(relation.evidenceActivityIDs)
                == contract.relationEvidenceIDs
        )
        #expect(relation.sourceConceptIDs.allSatisfy(catalogIDs.contains))
        #expect(relation.targetConceptIDs.allSatisfy(catalogIDs.contains))
        #expect(relation.evidenceActivityIDs.allSatisfy(activityIDs.contains))
        let relationActivityID = try #require(relationSection.activityID)
        #expect(
            page.activities.first { $0.id == relationActivityID }?
                .isRequired == false
        )

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
