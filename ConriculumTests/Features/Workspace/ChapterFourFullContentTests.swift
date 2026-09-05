import AppKit
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing
@testable import Conriculum

@MainActor
struct ChapterFourFullContentTests {
    @Test
    func bundledChapterPreservesItsRouteAndSharedLearningContract() throws {
        let store = BundledContentStore()
        let chapter = try store.loadChapter("chapter-04")
        let previous = try store.loadChapter("chapter-03")
        #expect(chapter.stageID == "stage-01")
        #expect(chapter.order == 4)
        #expect(chapter.progressDenominator == 9)
        #expect(previous.progressPages.last?.navigation.next?.pageID == chapter.overview.id)
        #expect(chapter.overview.navigation.previous?.pageID == previous.progressPages.last?.id)
        #expect(chapter.progressPages.last?.navigation.next?.pageID == "chapter-05-page-01")
        #expect(chapter.progressPages.map(\.title) == [
            "자연어 조건을 질문으로 바꾸기", "참과 거짓을 값으로 바라보기",
            "비교 연산자로 조건 만들기", "경계가 포함되는지 판단하기",
            "여러 조건을 조합하기", "조건에 의미 있는 이름 붙이기",
            "반례로 조건 확인하기", "새로운 문제에 적용하고 돌아보기",
            "조건 흐름을 의미 단위 조각으로 읽기",
        ])
        let route = [chapter.overview] + chapter.progressPages
        for (left, right) in zip(route, route.dropFirst()) {
            #expect(left.navigation.next?.pageID == right.id)
            #expect(right.navigation.previous?.pageID == left.id)
        }
        for page in chapter.progressPages {
            #expect(LearningContentAssembly.isAssembled(page))
            let sections = page.sections.sorted { $0.order < $1.order }
            let compass = try #require(sections.first)
            #expect(compass.content.tag == .learningCompass)
            let closure = try #require(sections.first { $0.content.tag == .learningClosure })
            let work = try #require(sections.first {
                [.choiceWithReason, .freeResponse, .semanticChunkReading].contains($0.content.tag)
            })
            #expect(compass.order < work.order && work.order < closure.order)
            #expect(page.knowledgeLinks.filter { $0.role == .primary }.count == 1)
            #expect(page.knowledgeLinks.filter { $0.role == .supporting }.count <= 2)
            #expect(Set(page.knowledgeContext.currentlyUsedConceptIDs) == Set(page.knowledgeLinks.map(\.conceptID)))
            for section in [compass, work, closure] {
                #expect(page.activities.contains { $0.sectionID == section.id && $0.isRequired })
            }
            for optional in sections where [.enrichmentTask, .personalKnowledgePromotion].contains(optional.content.tag) {
                #expect(optional.order > closure.order)
                if let activityID = optional.activityID {
                    #expect(page.activities.first { $0.id == activityID }?.isRequired == false)
                }
            }
        }
    }

    @Test
    func transferWithholdsGuidanceAndFinalLessonConnectsNonContiguousConditions() throws {
        let chapter = try BundledContentStore().loadChapter("chapter-04")
        let transfer = try #require(chapter.page(id: "chapter-04-page-08"))
        #expect(!transfer.sections.contains { $0.content.tag == .decisionCriteria })
        let activity = try #require(transfer.sections.first { $0.content.tag == .freeResponse })
        guard case let .freeResponse(task) = activity.content else { return }
        #expect(task.exampleAfterSubmission.contains("age >= 12 && age <= 18"))
        #expect(task.exampleAfterSubmission.contains("hasConsent || isMember"))
        let final = try #require(chapter.progressPages.last)
        let section = try #require(final.sections.first { $0.content.tag == .semanticChunkReading })
        guard case let .semanticChunkReading(chunk) = section.content else { return }
        #expect(chunk.elements.count == 8)
        #expect(chunk.elements.map(\.text).joined(separator: "\n") == chunk.code)
        #expect(chunk.selectionPrompt.contains("떨어진"))
        #expect(chunk.boundaryPrompt.contains("bannerText"))
        #expect(chunk.changePrompt.contains("isMember"))
        #expect(chunk.changePrompt.contains("Chapter 5"))
        #expect(chunk.completionEvidence.contains("비연속 요소 연결"))
        #expect(chunk.completionEvidence.contains("변경 영향"))
    }

    @Test
    func conditionResponseSurvivesAutosaveAndReloadThroughRealPersistence() async throws {
        let assembly = try AppAssembly.inMemory()
        let chapter = try await assembly.curriculumClient.loadChapter("chapter-04")
        let page = try #require(chapter.page(id: "chapter-04-page-05"))
        let activityID = try #require(page.sections.first { $0.content.tag == .freeResponse }?.activityID)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_004)
        let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000405")!
        let fields = [ActivityResponseField(key: "response", values: ["둘 다 참일 때도 ||는 true다."])]
        let draft = ChapterLearningFeature.ActivityDraft(
            responseID: ActivityResponseID(rawValue: uuid.uuidString.lowercased()),
            activityID: activityID, fields: fields
        )
        var state = ChapterLearningFeature.State(chapterID: chapter.id, currentPageID: page.id)
        state.chapter = chapter
        let clock = TestClock()
        let store = TestStore(initialState: state) { ChapterLearningFeature() } withDependencies: {
            $0.continuousClock = clock
            $0.date.now = timestamp
            $0.uuid = .constant(uuid)
            $0.learningRecordClient = assembly.learningRecordClient
        }
        await store.send(.activityDraftChanged(activityID: activityID, fields: fields)) {
            $0.activityDrafts[activityID] = draft
            $0.activitySaveStates[activityID] = .pending
        }
        await clock.advance(by: .milliseconds(750))
        await store.receive(.activityAutosaveDelayElapsed(activityID)) {
            $0.activitySaveStates[activityID] = .saving
        }
        await store.receive(.activitySaveResponse(activityID: activityID, response: .saved(draft: draft, savedAt: timestamp))) {
            $0.activitySaveStates[activityID] = .saved(timestamp)
        }
        let reopened = UserDataStore(modelContainer: assembly.modelContainer)
        let responses = try reopened.loadResponses(pageID: page.id)
        #expect(responses.count == 1)
        #expect(responses.first?.activityID == activityID)
        #expect(responses.first?.fields == fields)
        #expect(try reopened.loadAllRevisions().isEmpty)
    }

    @Test
    func everySectionRendersAtNarrowAndRegularWidths() throws {
        let content = BundledContentStore()
        let chapter = try content.loadChapter("chapter-04")
        let names = KnowledgeConceptNames(catalog: try content.loadCatalog())
        for page in chapter.allPages {
            for section in page.sections {
                for width in [480.0, 760.0] {
                    let activity = section.activityID.map {
                        LearningActivityInput(activityID: $0, fields: []) { _, _ in }
                    }
                    let view = LearningSectionView(
                        section: section, conceptNames: names, activity: activity,
                        componentState: .init(), onComponentAction: { _ in }
                    )
                    .padding(24)
                    .frame(width: width)
                    .fixedSize(horizontal: false, vertical: true)
                    let host = NSHostingView(rootView: view)
                    let size = host.fittingSize
                    #expect(size.width <= width + 1)
                    #expect(size.height.isFinite && size.height > 0)
                    host.frame = NSRect(origin: .zero, size: size)
                    host.layoutSubtreeIfNeeded()
                    // Export representative real components for visual read-back.
                    if width == 480, ["section-ch04-page05-work", "section-ch04-page09-work"].contains(section.id.rawValue) {
                        let image = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                        host.cacheDisplay(in: host.bounds, to: image)
                        let png = try #require(image.representation(using: .png, properties: [:]))
                        try png.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(section.id.rawValue).png"))
                    }
                }
            }
        }
    }
}
