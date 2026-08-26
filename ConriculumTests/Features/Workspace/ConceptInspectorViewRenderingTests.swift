import AppKit
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct ConceptInspectorViewRenderingTests {
    @Test
    func revisionRelationAndCandidateStatesRenderAtInspectorWidth() throws {
        let states = [
            state(revision: nil),
            state(revision: revision),
            relationEditorState(),
            activityCandidateState(),
        ]

        for state in states {
            let view = ConceptInspectorView(
                store: Store(initialState: state) {
                    ConceptInspectorFeature()
                }
            )
            .frame(width: 380, height: 760)
            .background(Color(nsColor: .windowBackgroundColor))
            let hostingView = NSHostingView(rootView: view)
            hostingView.frame = NSRect(x: 0, y: 0, width: 380, height: 760)
            let window = NSWindow(
                contentRect: hostingView.frame,
                styleMask: [],
                backing: .buffered,
                defer: false
            )
            window.contentView = hostingView
            window.layoutIfNeeded()
            hostingView.layoutSubtreeIfNeeded()
            let image = try #require(
                hostingView.bitmapImageRepForCachingDisplay(
                    in: hostingView.bounds
                )
            )
            hostingView.cacheDisplay(in: hostingView.bounds, to: image)

            #expect(image.size == NSSize(width: 380, height: 760))
            #expect(sampledColorCount(in: image) > 4)
        }
    }

    private func state(
        revision: PersonalConceptRevision?
    ) -> ConceptInspectorFeature.State {
        ConceptInspectorFeature.State(
            sourcePageTitle: "변경 가능성으로 let과 var 판단하기",
            item: KnowledgeContextSnapshot.ConceptItem(
                concept: concept,
                personalRevision: revision,
                revisionEvidenceActivityID: "activity-page05-card-sorting",
                role: .primary,
                usage: "현재 책임의 값 변경 여부를 판단한다.",
                nearbyReason: nil
            )
        )
    }

    private var concept: KnowledgeConcept {
        KnowledgeConcept(
            id: "concept-constants-variables",
            title: "상수와 변수",
            definition: "상수는 같은 이름에 다른 값을 넣지 않는 선언이고 변수는 필요할 때 다시 넣을 수 있는 선언이다.",
            essentialQuestion: "이 책임 안에서 같은 이름의 값이 바뀌어야 하는가?",
            judgmentQuestions: ["값 변경이 이 범위의 책임인가?"],
            examples: ["주문 번호는 let", "현재 재생 위치는 var"],
            misconceptions: []
        )
    }

    private var revision: PersonalConceptRevision {
        PersonalConceptRevision(
            id: "revision-rendering-constants",
            conceptID: concept.id,
            personalTitle: "변경 책임 약속",
            explanation: "현재 책임 안에서 같은 이름에 새 값을 넣을지를 판단한다.",
            examples: [
                PersonalExample(
                    id: "example-rendering-order",
                    text: "주문 번호는 바뀌지 않는다.",
                    context: "주문 생성"
                )
            ],
            previousRevisionID: nil,
            evidenceActivityID: "activity-page05-choice",
            createdAt: Date(timeIntervalSince1970: 1_725_782_400)
        )
    }

    private func relationEditorState() -> ConceptInspectorFeature.State {
        let target = KnowledgeConcept(
            id: "concept-identifier-naming",
            title: "식별자와 이름 짓기",
            definition: "이름으로 값의 역할을 드러낸다.",
            essentialQuestion: "이 이름이 값의 역할을 말하는가?",
            judgmentQuestions: [],
            examples: [],
            misconceptions: []
        )
        let contract = KnowledgeContextSnapshot.RelationCreationContract(
            sourceConceptIDs: [concept.id],
            targetConceptIDs: [target.id],
            draftStatement: "변경 책임을 정한 뒤 역할이 드러나는 이름을 붙인다.",
            reasonPrompt: "두 개념을 연결한 이유",
            evidenceActivityID: "activity-page08-value-sorting"
        )
        let request = PersonalRelationDraftRequest(
            sourceConceptID: concept.id,
            targetConceptID: target.id,
            statement: contract.draftStatement,
            reason: "선언과 이름이 같은 책임을 설명하기 때문이다.",
            evidenceActivityID: contract.evidenceActivityID
        )
        var state = ConceptInspectorFeature.State(
            sourcePageTitle: "챕터 2 판단 흐름 다시 사용하기",
            item: KnowledgeContextSnapshot.ConceptItem(
                concept: concept,
                personalRevision: revision,
                revisionEvidenceActivityID: "activity-page08-free-response",
                role: .primary,
                usage: "변경 책임과 역할 이름을 함께 판단한다.",
                nearbyReason: nil
            ),
            availableConcepts: [concept, target],
            personalRelations: [],
            relationCreationContract: contract
        )
        state.relationEditor = PersonalRelationEditorFeature.State(
            request: request,
            contract: contract,
            availableConcepts: [concept, target]
        )
        return state
    }

    private func activityCandidateState() -> ConceptInspectorFeature.State {
        let boundary = KnowledgeConcept(
            id: "concept-problem-boundary",
            title: "문제의 경계",
            definition: "해결이 책임질 범위를 나눈다.",
            essentialQuestion: "이번 해결은 어디까지 책임지는가?",
            judgmentQuestions: [],
            examples: [],
            misconceptions: []
        )
        let review = KnowledgePersonalizationReview(
            candidate: KnowledgePersonalizationCandidate(
                id: "candidate-rendering-constants",
                kind: .conceptRevision,
                conceptIDs: [concept.id, boundary.id],
                draft: "변경 가능성은 현재 책임과 시간 범위 안에서 판단한다.",
                evidenceActivityID: "activity-page05-card-sorting",
                createdAt: Date(timeIntervalSince1970: 1_725_782_400)
            ),
            targetConceptID: concept.id,
            activityID: "activity-page05-promotion",
            confirmationQuestion:
                "이 문장을 나의 변경 책임 기준으로 남길까?",
            savedFields: ["나의 설명", "판단 경계", "근거 활동 ID", "수정 시각"]
        )
        return ConceptInspectorFeature.State(
            sourcePageTitle: "변하지 않는 값을 선언하기",
            item: KnowledgeContextSnapshot.ConceptItem(
                concept: concept,
                personalRevision: revision,
                revisionEvidenceActivityID: "activity-page05-card-sorting",
                role: .primary,
                usage: "현재 책임의 값 변경 여부를 판단한다.",
                nearbyReason: nil
            ),
            availableConcepts: [concept, boundary],
            personalizationReview: review
        )
    }

    private func sampledColorCount(in image: NSBitmapImageRep) -> Int {
        let horizontalStep = max(image.pixelsWide / 20, 1)
        let verticalStep = max(image.pixelsHigh / 20, 1)
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
