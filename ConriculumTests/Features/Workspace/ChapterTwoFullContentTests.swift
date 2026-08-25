import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct ChapterTwoFullContentTests {
    private struct PageReadBackContract {
        let title: String
        let goal: String
        let requiredActivityCount: Int
        let knowledgeLinkCount: Int
    }

    private let timestamp = Date(timeIntervalSince1970: 1_725_782_400)

    @Test
    func sourceGoalsAndEvidenceCountsSurviveTheTypedFixture() throws {
        let chapter = try loadChapter()
        let contracts = [
            PageReadBackContract(
                title: "현실의 정보를 값으로 바라보기",
                goal: "현실의 설명에서 프로그램이 하나씩 다룰 구체적인 값을 찾고 값과 규칙을 구분한다.",
                requiredActivityCount: 4,
                knowledgeLinkCount: 3
            ),
            PageReadBackContract(
                title: "값의 종류 비교하기",
                goal: "값의 표기와 할 수 있는 일을 비교해 String, Int, Double, Bool의 차이를 설명한다.",
                requiredActivityCount: 4,
                knowledgeLinkCount: 5
            ),
            PageReadBackContract(
                title: "정보에 맞는 타입 선택하기",
                goal: "정보의 겉모양이 아니라 의미, 허용할 상태, 이후 할 일을 근거로 타입을 선택한다.",
                requiredActivityCount: 4,
                knowledgeLinkCount: 5
            ),
            PageReadBackContract(
                title: "의미가 드러나는 이름 붙이기",
                goal: "값의 대상과 역할이 코드에서 드러나도록 Swift 식별자를 만들고 선택 근거를 설명한다.",
                requiredActivityCount: 4,
                knowledgeLinkCount: 1
            ),
            PageReadBackContract(
                title: "변하지 않는 값을 선언하기",
                goal: "현재 책임과 시간 범위에서 값이 바뀌어야 하는지 판단하고 변하지 않는 값을 let으로 선언한다.",
                requiredActivityCount: 4,
                knowledgeLinkCount: 2
            ),
            PageReadBackContract(
                title: "타입 명시와 타입 추론 비교하기",
                goal: "Swift가 추론한 타입과 개발자가 직접 명시한 타입을 읽고 의도를 드러낼 표기 방식을 선택한다.",
                requiredActivityCount: 4,
                knowledgeLinkCount: 3
            ),
            PageReadBackContract(
                title: "여러 정보를 값으로 구조화하기",
                goal: "한 사례를 설명하는 여러 선언을 역할에 따라 묶고 포함하거나 제외한 이유를 설명한다.",
                requiredActivityCount: 4,
                knowledgeLinkCount: 3
            ),
            PageReadBackContract(
                title: "새로운 문제에 적용하고 돌아보기",
                goal: "새로운 맥락의 정보를 Swift 선언으로 옮기고 값·타입·이름·변경 가능성에 대한 선택 근거를 설명한다.",
                requiredActivityCount: 6,
                knowledgeLinkCount: 6
            ),
        ]

        #expect(chapter.progressDenominator == contracts.count)
        #expect(chapter.progressPages.map(\.order) == Array(1...8))

        for (page, contract) in zip(chapter.progressPages, contracts) {
            #expect(page.title == contract.title)
            #expect(page.goal == contract.goal)
            #expect(
                page.activities.filter(\.isRequired).count
                    == contract.requiredActivityCount
            )
            #expect(page.knowledgeLinks.count == contract.knowledgeLinkCount)
        }
    }

    @Test
    func everyLessonHasACompleteSharedContentContract() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let catalogIDs = Set(catalog.concepts.map(\.id))

        #expect(Chapter02ContentAssembly.isAssembled(chapter.overview))
        #expect(chapter.progressPages.allSatisfy(
            Chapter02ContentAssembly.isAssembled
        ))
        #expect(Set(chapter.allPages.map(\.id)).count == 9)

        for page in chapter.progressPages {
            let sectionIDs = Set(page.sections.map(\.id))
            let activityIDs = Set(page.activities.map(\.id))
            let directConceptIDs = Set(page.knowledgeLinks.map(\.conceptID))

            #expect(!page.title.isEmpty)
            #expect(!page.goal.isEmpty)
            #expect(
                page.sections.map(\.order)
                    == Array(1...page.sections.count)
            )
            #expect(sectionIDs.count == page.sections.count)
            #expect(activityIDs.count == page.activities.count)
            #expect(!page.activities.filter(\.isRequired).isEmpty)
            #expect(page.sections.compactMap(\.activityID).allSatisfy(
                activityIDs.contains
            ))
            #expect(page.activities.allSatisfy {
                sectionIDs.contains($0.sectionID)
            })
            #expect(directConceptIDs.allSatisfy(catalogIDs.contains))
            #expect(
                Set(page.knowledgeContext.currentlyUsedConceptIDs)
                    .isSubset(of: directConceptIDs)
            )
            #expect(page.knowledgeContext.nearbyKnowledge.allSatisfy {
                catalogIDs.contains($0.conceptID) && !$0.reason.isEmpty
            })
            #expect(!page.knowledgeContext.currentlyUsedSummary.isEmpty)
            #expect(!page.knowledgeContext.changedKnowledgeSummary.isEmpty)
            #expect(!page.knowledgeContext.refreshTriggers.isEmpty)
            #expect(!page.knowledgeContext.emptyStateMessage.isEmpty)
            #expect(!page.knowledgeContext.focusModeSummary.isEmpty)

            try validateSharedSections(
                in: page,
                activityIDs: activityIDs,
                catalogIDs: catalogIDs
            )
        }
    }

    @Test
    func chapterFixtureExercisesEverySharedRendererTag() throws {
        let chapter = try loadChapter()
        let chapterTags = Set(
            chapter.allPages.flatMap { page in
                page.sections.map(\.content.tag)
            }
        )

        #expect(chapterTags == Set(LearningSectionTag.allCases))
    }

    @Test
    func navigationMetadataFormsOneContinuousSourceRoute() throws {
        let chapter = try loadChapter()
        let pages = chapter.progressPages

        #expect(chapter.overview.navigation.previous == nil)
        #expect(chapter.overview.navigation.next?.pageID == pages[0].id)
        #expect(chapter.overview.navigation.next?.label == pages[0].title)

        for index in pages.indices {
            let page = pages[index]
            let expectedPrevious = index == pages.startIndex
                ? chapter.overview
                : pages[index - 1]

            #expect(page.navigation.previous?.pageID == expectedPrevious.id)
            #expect(page.navigation.previous?.label == expectedPrevious.title)

            if index < pages.index(before: pages.endIndex) {
                let expectedNext = pages[index + 1]
                #expect(page.navigation.next?.pageID == expectedNext.id)
                #expect(page.navigation.next?.label == expectedNext.title)
            } else {
                #expect(
                    page.navigation.next?.pageID
                        == LearningPageID(rawValue: "chapter-03-page-01")
                )
                #expect(page.navigation.next?.label == "값으로 새로운 값을 계산하기")
            }
        }

        var firstState = ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: pages[0].id
        )
        firstState.chapter = chapter
        #expect(!firstState.canNavigatePrevious)

        var lastState = ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: pages[7].id
        )
        lastState.chapter = chapter
        #expect(lastState.isLastPage)
    }

    @Test
    func everyLessonAutosavesItsOwnActivityDraft() async throws {
        let chapter = try loadChapter()

        for (index, page) in chapter.progressPages.enumerated() {
            let activity = try #require(
                page.activities.first { $0.isRequired }
            )
            let responseUUID = try #require(UUID(uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                index + 201
            )))
            let fields = [
                ActivityResponseField(
                    key: "readBack",
                    values: ["page-\(index + 1)-verified"]
                )
            ]
            let draft = ChapterLearningFeature.ActivityDraft(
                responseID: ActivityResponseID(
                    rawValue: responseUUID.uuidString.lowercased()
                ),
                activityID: activity.id,
                fields: fields
            )
            let clock = TestClock()
            var state = ChapterLearningFeature.State(
                chapterID: chapter.id,
                currentPageID: page.id
            )
            state.chapter = chapter
            let store = TestStore(initialState: state) {
                ChapterLearningFeature()
            } withDependencies: {
                $0.continuousClock = clock
                $0.date.now = timestamp
                $0.uuid = .constant(responseUUID)
                $0.learningRecordClient.saveResponse = { response in
                    #expect(response.id == draft.responseID)
                    #expect(response.activityID == activity.id)
                    #expect(response.pageID == page.id)
                    #expect(response.fields == fields)
                    #expect(response.recordedAt == timestamp)
                }
            }

            await store.send(.activityDraftChanged(
                activityID: activity.id,
                fields: fields
            )) {
                $0.activityDrafts[activity.id] = draft
                $0.activitySaveStates[activity.id] = .pending
            }
            await clock.advance(by: .milliseconds(750))
            await store.receive(.activityAutosaveDelayElapsed(activity.id)) {
                $0.activitySaveStates[activity.id] = .saving
            }
            await store.receive(.activitySaveResponse(
                activityID: activity.id,
                response: .saved(draft: draft, savedAt: timestamp)
            )) {
                $0.activitySaveStates[activity.id] = .saved(timestamp)
            }
        }
    }

    private func validateSharedSections(
        in page: LearningPage,
        activityIDs: Set<LearningActivityID>,
        catalogIDs: Set<KnowledgeConceptID>
    ) throws {
        let requiredTags: [LearningSectionTag] = [
            .personalExpressionComparison,
            .learningStateSelection,
            .enrichmentTask,
            .personalKnowledgePromotion,
            .completionCheck,
        ]
        for tag in requiredTags {
            #expect(page.sections.filter { $0.content.tag == tag }.count == 1)
        }

        let comparisonSection = try #require(
            page.sections.first {
                $0.content.tag == .personalExpressionComparison
            }
        )
        guard case let .personalExpressionComparison(comparison) =
            comparisonSection.content
        else {
            Issue.record("기본·나의 표현 비교 mapping이 올바르지 않다.")
            return
        }
        #expect(!comparison.conceptIDs.isEmpty)
        #expect(comparison.conceptIDs.allSatisfy(catalogIDs.contains))

        let stateSection = try #require(
            page.sections.first {
                $0.content.tag == .learningStateSelection
            }
        )
        guard case let .learningStateSelection(stateSelection) =
            stateSection.content
        else {
            Issue.record("학습 상태 mapping이 올바르지 않다.")
            return
        }
        let stateIDs = Set(stateSelection.options.map(\.id))
        #expect(!stateIDs.isEmpty)

        let enrichmentSection = try #require(
            page.sections.first { $0.content.tag == .enrichmentTask }
        )
        guard case let .enrichmentTask(enrichment) = enrichmentSection.content
        else {
            Issue.record("확장·심화 과제 mapping이 올바르지 않다.")
            return
        }
        #expect(stateIDs.contains(enrichment.requiredStateID))
        #expect(!enrichment.prompt.isEmpty)
        #expect(enrichment.conceptIDs.allSatisfy(catalogIDs.contains))

        let promotionSection = try #require(
            page.sections.first {
                $0.content.tag == .personalKnowledgePromotion
            }
        )
        guard case let .personalKnowledgePromotion(promotion) =
            promotionSection.content
        else {
            Issue.record("개인 지식 반영 mapping이 올바르지 않다.")
            return
        }
        #expect(!promotion.evidenceActivityIDs.isEmpty)
        #expect(promotion.evidenceActivityIDs.allSatisfy(activityIDs.contains))
        #expect(!promotion.conceptIDs.isEmpty)
        #expect(promotion.conceptIDs.allSatisfy(catalogIDs.contains))
        #expect(!promotion.editableDraft.isEmpty)
        #expect(!promotion.confirmationQuestion.isEmpty)
        let promotionActivityID = try #require(promotionSection.activityID)
        #expect(
            page.activities.first { $0.id == promotionActivityID }?
                .isRequired == false
        )

        let completionSection = try #require(
            page.sections.first { $0.content.tag == .completionCheck }
        )
        guard case let .completionCheck(completion) = completionSection.content
        else {
            Issue.record("완료 판단 mapping이 올바르지 않다.")
            return
        }
        #expect(!completion.question.isEmpty)
        #expect(!completion.requiredEvidence.isEmpty)
        #expect(!completion.retryCondition.isEmpty)
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
}
