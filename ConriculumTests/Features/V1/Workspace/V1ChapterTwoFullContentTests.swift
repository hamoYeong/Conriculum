import ComposableArchitecture
import Foundation
import Testing

@testable import Conriculum

@MainActor
struct V1ChapterTwoFullContentTests {
    private struct PageReadBackContract {
        let title: String
        let goal: String
        let requiredActivityCount: Int
        let knowledgeLinkCount: Int
    }

    private let timestamp = Date(timeIntervalSince1970: 1_725_782_400)

    @Test
    func allNineLessonsReadBackFromTheObsidianDerivedResource() throws {
        let chapter = try loadChapter()
        let contracts = [
            PageReadBackContract(
                title: "현실의 정보를 값으로 바라보기",
                goal: "현실의 설명에서 현재 사례의 구체적인 값을 찾고, 여러 사례에 반복되는 규칙과 구분한다.",
                requiredActivityCount: 5,
                knowledgeLinkCount: 3
            ),
            PageReadBackContract(
                title: "값의 종류 비교하기",
                goal: "값의 표기와 허용되는 일을 비교해 `String`, `Int`, `Double`, `Bool`의 차이를 설명한다.",
                requiredActivityCount: 5,
                knowledgeLinkCount: 5
            ),
            PageReadBackContract(
                title: "정보에 맞는 타입 선택하기",
                goal: "정보의 겉모양이 아니라 의미, 허용할 상태, 이후 할 일을 근거로 타입을 선택한다.",
                requiredActivityCount: 5,
                knowledgeLinkCount: 5
            ),
            PageReadBackContract(
                title: "의미가 드러나는 이름 붙이기",
                goal: "값의 대상과 역할이 코드에서 드러나도록 Swift 식별자를 만들고 선택 근거를 설명한다.",
                requiredActivityCount: 5,
                knowledgeLinkCount: 1
            ),
            PageReadBackContract(
                title: "변하지 않는 값을 선언하기",
                goal: "현재 책임과 시간 범위에서 재할당이 필요한지를 판단해 `let`과 `var`를 선택한다.",
                requiredActivityCount: 5,
                knowledgeLinkCount: 2
            ),
            PageReadBackContract(
                title: "타입 명시와 타입 추론 비교하기",
                goal: "타입 표기가 없어도 Swift가 알아낸 타입을 읽고, 의도를 드러낼 필요에 따라 추론과 명시를 선택한다.",
                requiredActivityCount: 5,
                knowledgeLinkCount: 3
            ),
            PageReadBackContract(
                title: "여러 정보를 값으로 구조화하기",
                goal: "한 사례를 설명하는 여러 선언을 타입별이 아니라 대상·역할·책임으로 묶고 포함·제외 경계를 설명한다.",
                requiredActivityCount: 5,
                knowledgeLinkCount: 3
            ),
            PageReadBackContract(
                title: "새로운 문제에 적용하고 돌아보기",
                goal: "복습 자료를 먼저 보지 않고 새 맥락의 정보를 Swift 선언으로 옮긴 뒤, 자신이 사용한 판단 순서와 근거를 설명한다.",
                requiredActivityCount: 7,
                knowledgeLinkCount: 6
            ),
            PageReadBackContract(
                title: "선언 묶음을 의미 단위 조각으로 읽기",
                goal: "선언의 물리적 순서나 같은 타입에 기대지 않고, 서로 떨어진 선언을 같은 사례·역할·책임의 의미 단위 조각으로 묶어 코드의 의도를 설명한다.",
                requiredActivityCount: 5,
                knowledgeLinkCount: 3
            ),
        ]

        #expect(chapter.progressDenominator == contracts.count)
        #expect(chapter.progressPages.map(\.order) == Array(1...9))

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
    func everyLessonHasTheSharedMacroAndReferenceContract() throws {
        let chapter = try loadChapter()
        let catalog = try loadKnowledgeCatalog()
        let catalogIDs = Set(catalog.concepts.map(\.id))
        let optionalTags: Set<V1LearningSectionTag> = [
            .enrichmentTask,
            .personalKnowledgePromotion,
            .personalKnowledgeRelation,
            .knowledgeChangeSummary,
        ]

        #expect(V1LearningContentAssembly.isAssembled(chapter.overview))
        #expect(chapter.progressPages.allSatisfy(
            V1LearningContentAssembly.isAssembled
        ))
        #expect(Set(chapter.allPages.map(\.id)).count == 10)

        for page in chapter.progressPages {
            let sectionIDs = Set(page.sections.map(\.id))
            let activityIDs = Set(page.activities.map(\.id))
            let directConceptIDs = Set(page.knowledgeLinks.map(\.conceptID))
            let compassSection = try #require(
                page.sections.first { $0.content.tag == .learningCompass }
            )
            let closureSection = try #require(
                page.sections.first { $0.content.tag == .learningClosure }
            )
            let closureActivityID = try #require(closureSection.activityID)

            #expect(page.sections.first?.content.tag == .learningCompass)
            #expect(page.sections.filter {
                $0.content.tag == .learningCompass
            }.count == 1)
            #expect(page.sections.filter {
                $0.content.tag == .learningClosure
            }.count == 1)
            #expect(page.sections.map(\.order) == Array(1...page.sections.count))
            #expect(sectionIDs.count == page.sections.count)
            #expect(activityIDs.count == page.activities.count)
            #expect(page.sections.compactMap(\.activityID).allSatisfy(
                activityIDs.contains
            ))
            #expect(page.activities.allSatisfy {
                sectionIDs.contains($0.sectionID)
            })
            #expect(
                page.activities.first { $0.id == compassSection.activityID }?
                    .isRequired == true
            )
            #expect(
                page.activities.first { $0.id == closureActivityID }?
                    .isRequired == true
            )
            #expect(page.sections.allSatisfy {
                optionalTags.contains($0.content.tag) == false
                    || $0.order > closureSection.order
            })

            #expect(page.knowledgeLinks.filter { $0.role == .primary }.count == 1)
            #expect(directConceptIDs.allSatisfy(catalogIDs.contains))
            #expect((1...3).contains(
                page.knowledgeContext.currentlyUsedConceptIDs.count
            ))
            #expect(
                Set(page.knowledgeContext.currentlyUsedConceptIDs)
                    .isSubset(of: directConceptIDs)
            )
            #expect(page.knowledgeContext.nearbyKnowledge.allSatisfy {
                catalogIDs.contains($0.conceptID) && !$0.reason.isEmpty
            })
            #expect(!page.knowledgeContext.currentlyUsedSummary.isEmpty)
            #expect(!page.knowledgeContext.changedKnowledgeSummary.isEmpty)
            #expect(!page.knowledgeContext.emptyStateMessage.isEmpty)

            let enrichmentSection = try #require(
                page.sections.first { $0.content.tag == .enrichmentTask }
            )
            guard case let .enrichmentTask(enrichment) =
                enrichmentSection.content
            else {
                Issue.record("선택 학습 mapping이 올바르지 않다.")
                return
            }
            #expect(enrichment.title == "더 깊게 가기")
            #expect(!enrichment.guidance.isEmpty)
            #expect(enrichmentSection.activityID == nil)
        }
    }

    @Test
    func chapterFixtureExercisesEveryRendererTag() throws {
        let chapter = try loadChapter()
        let chapterTags = Set(
            chapter.allPages.flatMap { page in
                page.sections.map(\.content.tag)
            }
        )

        #expect(chapterTags == Set(V1LearningSectionTag.allCases))
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
                #expect(page.navigation.next?.pageID == "chapter-03-page-01")
                #expect(
                    page.navigation.next?.label
                        == "값으로 새로운 값을 계산하기"
                )
            }
        }

        var lastState = V1ChapterLearningFeature.State(
            chapterID: chapter.id,
            currentPageID: try #require(pages.last?.id)
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
                V1ActivityResponseField(
                    key: "readBack",
                    values: ["page-\(index + 1)-verified"]
                )
            ]
            let draft = V1ChapterLearningFeature.ActivityDraft(
                responseID: ActivityResponseID(
                    rawValue: responseUUID.uuidString.lowercased()
                ),
                activityID: activity.id,
                fields: fields
            )
            let clock = TestClock()
            var state = V1ChapterLearningFeature.State(
                chapterID: chapter.id,
                currentPageID: page.id
            )
            state.chapter = chapter
            let store = TestStore(initialState: state) {
                V1ChapterLearningFeature()
            } withDependencies: {
                $0.continuousClock = clock
                $0.date.now = timestamp
                $0.uuid = .constant(responseUUID)
                $0.v1LearningRecordClient.saveResponse = { response in
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
