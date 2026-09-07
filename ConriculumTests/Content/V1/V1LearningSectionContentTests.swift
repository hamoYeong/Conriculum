import Foundation
import Testing

@testable import Conriculum

// MARK: - 역할이 겹치지 않는 tag와 payload의 실제 최소 호출 예제

struct V1LearningSectionContentTests {
    /// 모든 지원 case가 `tag + payload` JSON으로 encode/decode되며 tag 목록과 정확히 일치하는지 확인한다.
    @Test
    func everySupportedTagRoundTrips() throws {
        let fixtures = makeFixtures()

        #expect(fixtures.count == 21)
        #expect(Set(fixtures.map(\.tag)) == Set(V1LearningSectionTag.allCases))

        for fixture in fixtures {
            let data = try JSONEncoder().encode(fixture)
            let envelope = try JSONDecoder().decode(TagEnvelope.self, from: data)
            let decoded = try JSONDecoder().decode(V1LearningSectionContent.self, from: data)

            #expect(envelope.tag == fixture.tag.rawValue)
            #expect(decoded == fixture)
        }
    }

    /// vocabulary 밖의 tag가 원래 값과 `tag` field path를 포함해 보고되는지 확인한다.
    @Test
    func unsupportedTagReportsTagAndFieldPath() throws {
        let data = Data(#"{"tag":"videoLesson","payload":{}}"#.utf8)

        do {
            _ = try JSONDecoder().decode(V1LearningSectionContent.self, from: data)
            Issue.record("지원하지 않는 tag가 decoding되었다.")
        } catch let error as V1UnsupportedLearningSectionTagError {
            #expect(error.tag == "videoLesson")
            #expect(error.codingPath == ["tag"])
            #expect(error.description.contains("videoLesson"))
        } catch {
            Issue.record("예상하지 못한 오류: \(error)")
        }
    }

    /// tag는 유효해도 해당 payload의 필수 field가 없으면 정확한 payload 경로에서 실패하는지 확인한다.
    @Test
    func missingPayloadFieldReportsItsCodingKey() throws {
        let data = Data(
            #"{"tag":"learningCompass","payload":{"previousConnection":"앞선 판단","coreQuestion":"무엇을 판단할까?","firstPredictionPrompt":"먼저 예상한다.","confidencePrompt":"확신을 고른다."}}"#.utf8
        )

        do {
            _ = try JSONDecoder().decode(V1LearningSectionContent.self, from: data)
            Issue.record("필수 payload field 없이 decoding되었다.")
        } catch let DecodingError.keyNotFound(key, context) {
            #expect(key.stringValue == "completionEvidence")
            #expect(context.codingPath.map(\.stringValue) == ["payload"])
        } catch {
            Issue.record("예상하지 못한 오류: \(error)")
        }
    }

    /// 모든 associated payload의 최소 유효값 모음.
    /// 각 구조체의 field 의미를 실제 생성 호출로 훑고 싶을 때 이 배열을 위에서 아래로 읽는다.
    private func makeFixtures() -> [V1LearningSectionContent] {
        let item = V1LearningContentItem(id: "item", text: "내용")
        let labeledText = V1LabeledText(label: "자료", text: "내용")
        let link = V1LearningKnowledgeLink(
            conceptID: "concept-value",
            role: .primary,
            usage: "현재 활동의 판단 기준으로 쓴다.",
            displayTiming: "활동 제출 뒤"
        )

        return [
            .learningCompass(
                V1LearningCompassContent(
                    previousConnection: "앞선 판단을 이어 쓴다.",
                    coreQuestion: "지금 무엇을 판단할까?",
                    firstPredictionPrompt: "첫 예상을 적는다.",
                    confidencePrompt: "현재 확신과 이유를 고른다.",
                    completionEvidence: ["판단과 근거"]
                )
            ),
            .situation(
                V1SituationContent(
                    title: "상황",
                    description: "판단할 맥락",
                    materials: [labeledText],
                    firstQuestion: "무엇을 찾을까?"
                )
            ),
            .comparison(
                V1ComparisonContent(
                    criterion: "역할",
                    items: [
                        V1ComparisonItem(id: "comparison", title: "항목", body: "설명", details: [labeledText])
                    ],
                    observationQuestion: "무엇이 다른가?"
                )
            ),
            .definition(
                V1DefinitionContent(
                    conceptID: "concept-value",
                    title: "값",
                    definition: "구체적인 정보다.",
                    scope: "현재 사례"
                )
            ),
            .decisionCriteria(
                V1DecisionCriteriaContent(
                    questions: ["어떤 일을 해야 하는가?"],
                    sequence: ["의미", "할 일", "타입"],
                    caution: "겉모양만 보지 않는다."
                )
            ),
            .codeExplanation(
                V1CodeExplanationContent(
                    code: "let quantity = 2",
                    language: "swift",
                    focus: ["let"],
                    lineMeanings: ["수량을 선언한다."],
                    outOfScope: ["계산"],
                    displayTiming: nil
                )
            ),
            .processGuide(
                V1ProcessGuideContent(
                    steps: [V1ProcessStep(order: 1, title: "값 찾기", question: "무엇이 정해졌는가?")],
                    completionDescription: "선언과 근거를 완성한다."
                )
            ),
            .cardSorting(
                V1CardSortingContent(
                    cards: [item],
                    groups: [V1LearningContentItem(id: "group", text: "값")],
                    interaction: "카드를 옮긴다.",
                    completionCriteria: ["모두 분류한다."],
                    feedbackCriteria: ["판단 기준을 되묻는다."]
                )
            ),
            .matching(
                V1MatchingContent(
                    leftItems: [item],
                    rightItems: [V1LearningContentItem(id: "right", text: "대응")],
                    rule: "같은 의미를 잇는다.",
                    completionCriteria: ["모두 연결한다."]
                )
            ),
            .choiceWithReason(
                V1ChoiceWithReasonContent(
                    questions: [V1ChoiceQuestion(id: "question", prompt: "무엇을 고를까?", options: [item])],
                    reasonPrompt: "이유를 쓴다.",
                    feedbackCriteria: ["근거를 확인한다."]
                )
            ),
            .fillInBlank(
                V1FillInBlankContent(
                    template: "let value: {{type}} = 2",
                    blanks: [V1FillInBlankItem(id: "type", placeholder: "타입", options: ["Int"])],
                    completionCriteria: ["타입을 채운다."]
                )
            ),
            .codeAssembly(
                V1CodeAssemblyContent(
                    starterCode: "{{declaration}} quantity = 2",
                    pieces: [V1LearningContentItem(id: "let", text: "let")],
                    fixedParts: ["quantity", "=", "2"],
                    completionCriteria: ["선언을 완성한다."]
                )
            ),
            .freeResponse(
                V1FreeResponseContent(
                    prompt: "자신의 예를 쓴다.",
                    inputFormat: "정보 → 값 → 타입",
                    requiredEvidence: ["선택 이유"],
                    exampleAfterSubmission: "수량 → 2 → Int"
                )
            ),
            .recallCheck(
                V1RecallCheckContent(
                    questions: ["무엇을 근거로 타입을 골랐는가?"],
                    comparisonTarget: "첫 선언과 마지막 선언",
                    recordFields: ["바뀐 생각"]
                )
            ),
            .learningClosure(
                V1LearningClosureContent(
                    firstPredictionReference: "처음 적은 예상",
                    finalExplanationPrompt: "지금의 설명을 적는다.",
                    confidenceChangePrompt: "확신이 어떻게 바뀌었는가?",
                    changedCriterionPrompt: "어떤 기준을 바꿨는가?",
                    nextUsePrompt: "다음에는 어디에 쓸까?",
                    completionQuestion: "근거로 설명할 수 있는가?",
                    requiredEvidence: ["판단", "근거"],
                    retryCondition: "근거가 없으면 핵심 활동으로 돌아간다."
                )
            ),
            .semanticChunkReading(
                V1SemanticChunkReadingContent(
                    code: "let capacity = 12\nlet isPaid = true",
                    language: "swift",
                    lensQuestions: ["함께 무엇을 준비하는가?"],
                    elements: [item],
                    selectionPrompt: "같은 책임의 요소를 고른다.",
                    chunkNamePrompt: "조각 이름을 붙인다.",
                    flowPrompt: "흐름을 설명한다.",
                    boundaryPrompt: "포함·제외 근거를 적는다.",
                    changePrompt: "변경 영향을 예상한다.",
                    completionEvidence: ["떨어진 요소의 연결"]
                )
            ),
            .knowledgeLink(V1KnowledgeLinkSectionContent(links: [link])),
            .enrichmentTask(
                V1EnrichmentTaskContent(
                    title: "더 깊게 가기",
                    guidance: "필요할 때만 펼친다.",
                    materials: [labeledText],
                    prompt: "복잡도를 높여 적용한다.",
                    conceptIDs: ["concept-value"]
                )
            ),
            .personalKnowledgePromotion(
                V1PersonalKnowledgePromotionContent(
                    evidenceActivityIDs: ["activity-01"],
                    conceptIDs: ["concept-value"],
                    candidateKind: .conceptRevision,
                    editableDraft: "나의 설명",
                    confirmationQuestion: "저장할까?",
                    savedFields: ["설명", "예시"],
                    cancellationResult: "학습 응답만 유지한다."
                )
            ),
            .personalKnowledgeRelation(
                V1PersonalKnowledgeRelationSectionContent(
                    sourceConceptIDs: ["concept-value"],
                    targetConceptIDs: ["concept-type"],
                    draftStatement: "값은 타입으로 할 일을 제한한다.",
                    reasonPrompt: "왜 연결했는가?",
                    evidenceActivityIDs: ["activity-01"],
                    confirmationQuestion: "연결을 저장할까?"
                )
            ),
            .knowledgeChangeSummary(
                V1KnowledgeChangeSummaryContent(
                    confirmedExpressions: "확인된 표현",
                    confirmedRelations: "확인된 연결",
                    pendingCandidates: "대기 후보",
                    nextUseSuggestion: "다음 입력 모델링에 쓴다.",
                    emptyState: "아직 반영한 내용이 없다."
                )
            ),
        ]
    }
}

/// encode 결과에서 payload와 독립적으로 raw tag만 검사하기 위한 envelope fixture.
private struct TagEnvelope: Decodable {
    let tag: String
}

// MARK: - 다음 읽기: Conriculum/Content/V1/Resources/V1ContentResourceModels.swift
