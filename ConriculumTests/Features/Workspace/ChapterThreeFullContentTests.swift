import AppKit
import Foundation
import ComposableArchitecture
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct ChapterThreeFullContentTests {
    @Test
    func allNineLessonsMatchTheObsidianLearningRoute() throws {
        let chapter = try chapterThree()
        let expectedGoals = [
            "계산식을 쓰기 전에 어떤 입력이 어떤 관계를 거쳐 결과를 만드는지 설명한다.",
            "표현식이 값과 연산을 평가해 하나의 결과값이 되는 과정을 실행 전에 추적한다.",
            "자연어가 말하는 값의 관계를 근거로 산술 연산자를 선택한다.",
            "여러 관계가 섞인 계산을 의미가 드러나는 중간값으로 나누고 단계 흐름을 설명한다.",
            "연산자 우선순위와 괄호가 평가 순서와 결과를 어떻게 바꾸는지 설명한다.",
            "같은 산술 기호라도 수 타입의 계산 규칙이 결과에 미치는 영향을 비교한다.",
            "실행 전 예상한 중간값과 최종값을 print로 관찰하고 처음 달라진 단계를 찾는다.",
            "도움을 줄인 새 문제에서 관계·중간값·순서·타입·관찰을 하나의 흐름으로 적용한다.",
            "떨어진 입력·표현식·중간값·결과·관찰을 계산 책임의 의미 단위 조각으로 묶는다.",
        ]

        #expect(chapter.id == "chapter-03")
        #expect(chapter.order == 3)
        #expect(chapter.pages.count == 9)
        #expect(chapter.progressPages.map(\.goal) == expectedGoals)
        #expect(chapter.overview.sections.first?.content.tag == .learningCompass)
        #expect(chapter.allPages.allSatisfy(LearningContentAssembly.isAssembled))
    }

    @Test
    func everyLessonPreservesTheSharedMacroAndKnowledgeScope() throws {
        let chapter = try chapterThree()
        let optionalTags: Set<LearningSectionTag> = [
            .enrichmentTask,
            .personalKnowledgePromotion,
            .personalKnowledgeRelation,
            .knowledgeChangeSummary,
        ]

        for page in chapter.progressPages {
            let orderedSections = page.sections.sorted { $0.order < $1.order }
            let compass = try #require(orderedSections.first {
                $0.content.tag == .learningCompass
            })
            let closure = try #require(orderedSections.first {
                $0.content.tag == .learningClosure
            })
            let primaryLinks = page.knowledgeLinks.filter {
                $0.role == .primary
            }

            #expect(compass.order < closure.order)
            #expect(orderedSections.contains {
                Self.learnerWorkTags.contains($0.content.tag)
                    && $0.order > compass.order
                    && $0.order < closure.order
            })
            #expect(orderedSections.filter {
                optionalTags.contains($0.content.tag)
            }.allSatisfy { $0.order > closure.order })
            #expect(primaryLinks.count == 1)
            #expect((1...3).contains(
                page.knowledgeContext.currentlyUsedConceptIDs.count
            ))
            #expect(page.activities.contains {
                $0.sectionID == compass.id && $0.isRequired
            })
            #expect(page.activities.contains {
                $0.sectionID == closure.id && $0.isRequired
            })
        }
    }

    @Test
    func navigationUsesStableIDsAcrossOverviewAndNineLessons() throws {
        let chapter = try chapterThree()
        let route = [chapter.overview] + chapter.progressPages

        for index in route.indices {
            if index > route.startIndex {
                #expect(route[index].navigation.previous?.pageID == route[index - 1].id)
            }
            if index < route.index(before: route.endIndex) {
                #expect(route[index].navigation.next?.pageID == route[index + 1].id)
            }
        }

        #expect(chapter.progressPages.last?.navigation.next?.pageID == "chapter-04-overview")
    }

    @Test
    func lastLessonRequiresNonContiguousCalculationChunkEvidence() throws {
        let page = try #require(chapterThree().progressPages.last)
        let section = try #require(page.sections.first {
            $0.content.tag == .semanticChunkReading
        })

        guard case let .semanticChunkReading(content) = section.content else {
            Issue.record("마지막 lesson의 의미 단위 조각 payload를 읽지 못했습니다.")
            return
        }

        #expect(content.elements.count == 7)
        #expect(content.code.contains("bannerText"))
        #expect(content.code.contains("bookSubtotal"))
        #expect(content.selectionPrompt.contains("떨어진"))
        #expect(content.boundaryPrompt.contains("제외"))
        #expect(content.changePrompt.contains("participantCount"))
        #expect(content.completionEvidence.contains("비연속 요소 연결"))
        #expect(content.completionEvidence.contains("조각 사이 흐름"))
        #expect(content.completionEvidence.contains("변경 영향"))
    }

    @Test
    func overviewAndCalculationChunkRenderThroughTheSharedSwiftUIView()
        throws
    {
        let chapter = try chapterThree()
        let catalog = try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let pages = [
            chapter.overview,
            try #require(chapter.progressPages.last),
        ]

        for page in pages {
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
            hostingView.frame = NSRect(x: 0, y: 0, width: 760, height: 900)
            hostingView.layoutSubtreeIfNeeded()
            let image = try #require(
                hostingView.bitmapImageRepForCachingDisplay(
                    in: hostingView.bounds
                )
            )
            hostingView.cacheDisplay(in: hostingView.bounds, to: image)

            #expect(abs(image.size.width - 760) < 0.5)
            #expect(abs(image.size.height - 900) < 0.5)
            #expect(sampledColorCount(in: image) > 3)
        }
    }

    @Test
    func everyLessonAutosavesItsOwnRequiredActivityDraft() async throws {
        let chapter = try chapterThree()

        for (index, page) in chapter.progressPages.enumerated() {
            let activity = try #require(page.activities.first {
                $0.isRequired
            })
            let timestamp = Date(
                timeIntervalSince1970: 1_800_000_000 + Double(index)
            )
            let responseUUID = try #require(UUID(uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                index + 301
            )))
            let fields = [
                ActivityResponseField(
                    key: "readBack",
                    values: ["chapter-03-page-\(index + 1)-verified"]
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

    private static let learnerWorkTags: Set<LearningSectionTag> = [
        .cardSorting,
        .matching,
        .choiceWithReason,
        .fillInBlank,
        .codeAssembly,
        .freeResponse,
        .recallCheck,
        .semanticChunkReading,
    ]

    private func chapterThree() throws -> Chapter {
        try ContentResourceDecoder().decode(
            Chapter.self,
            from: .chapter(stageNumber: 1, chapterNumber: 3)
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
