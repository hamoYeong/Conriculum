// MARK: - Section 콘텐츠의 tagged schema

/// JSON `tag`에 허용되는 section vocabulary 전체.
/// 각 case는 아래 `V1LearningSectionContent`의 associated payload와 1:1로 대응한다.
enum V1LearningSectionTag: String, Codable, CaseIterable, Hashable, Sendable {
    // 읽기·관찰: 학습자가 먼저 이해할 재료
    case learningCompass
    case situation
    case comparison
    case definition
    case decisionCriteria
    case codeExplanation
    case processGuide

    // 학습자 작업: 입력과 판단을 요구하는 활동
    case cardSorting
    case matching
    case choiceWithReason
    case fillInBlank
    case codeAssembly
    case freeResponse
    case recallCheck
    case semanticChunkReading
    case learningClosure

    // 공통·분기: 지식 연결, 선택 흐름, 개인 지식 반영
    case knowledgeLink
    case enrichmentTask
    case personalKnowledgePromotion
    case personalKnowledgeRelation
    case knowledgeChangeSummary
}

/// `{ "tag": ..., "payload": ... }` JSON을 표현하는 tagged union.
/// `tag`가 payload의 구체 타입을 결정하므로 잘못된 조합을 Domain 안으로 들이지 않는다.
enum V1LearningSectionContent: Codable, Equatable, Sendable {
    case learningCompass(V1LearningCompassContent)
    case situation(V1SituationContent)
    case comparison(V1ComparisonContent)
    case definition(V1DefinitionContent)
    case decisionCriteria(V1DecisionCriteriaContent)
    case codeExplanation(V1CodeExplanationContent)
    case processGuide(V1ProcessGuideContent)
    case cardSorting(V1CardSortingContent)
    case matching(V1MatchingContent)
    case choiceWithReason(V1ChoiceWithReasonContent)
    case fillInBlank(V1FillInBlankContent)
    case codeAssembly(V1CodeAssemblyContent)
    case freeResponse(V1FreeResponseContent)
    case recallCheck(V1RecallCheckContent)
    case semanticChunkReading(V1SemanticChunkReadingContent)
    case learningClosure(V1LearningClosureContent)
    case knowledgeLink(V1KnowledgeLinkSectionContent)
    case enrichmentTask(V1EnrichmentTaskContent)
    case personalKnowledgePromotion(V1PersonalKnowledgePromotionContent)
    case personalKnowledgeRelation(V1PersonalKnowledgeRelationSectionContent)
    case knowledgeChangeSummary(V1KnowledgeChangeSummaryContent)

    private enum CodingKeys: String, CodingKey {
        case tag
        case payload
    }

    /// 현재 associated-value case를 JSON에 기록할 tag로 투영한다.
    var tag: V1LearningSectionTag {
        switch self {
        case .learningCompass: .learningCompass
        case .situation: .situation
        case .comparison: .comparison
        case .definition: .definition
        case .decisionCriteria: .decisionCriteria
        case .codeExplanation: .codeExplanation
        case .processGuide: .processGuide
        case .cardSorting: .cardSorting
        case .matching: .matching
        case .choiceWithReason: .choiceWithReason
        case .fillInBlank: .fillInBlank
        case .codeAssembly: .codeAssembly
        case .freeResponse: .freeResponse
        case .recallCheck: .recallCheck
        case .semanticChunkReading: .semanticChunkReading
        case .learningClosure: .learningClosure
        case .knowledgeLink: .knowledgeLink
        case .enrichmentTask: .enrichmentTask
        case .personalKnowledgePromotion: .personalKnowledgePromotion
        case .personalKnowledgeRelation: .personalKnowledgeRelation
        case .knowledgeChangeSummary: .knowledgeChangeSummary
        }
    }

    /// JSON → enum 변환.
    /// 먼저 raw `tag`를 검사하고, 그 tag에 대응하는 payload 타입으로만 decode한다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawTag = try container.decode(String.self, forKey: .tag)
        guard let tag = V1LearningSectionTag(rawValue: rawTag) else {
            throw V1UnsupportedLearningSectionTagError(
                tag: rawTag,
                codingPath: (decoder.codingPath + [CodingKeys.tag]).map(\.stringValue)
            )
        }

        switch tag {
        case .learningCompass:
            self = .learningCompass(
                try container.decode(V1LearningCompassContent.self, forKey: .payload)
            )
        case .situation:
            self = .situation(try container.decode(V1SituationContent.self, forKey: .payload))
        case .comparison:
            self = .comparison(try container.decode(V1ComparisonContent.self, forKey: .payload))
        case .definition:
            self = .definition(try container.decode(V1DefinitionContent.self, forKey: .payload))
        case .decisionCriteria:
            self = .decisionCriteria(try container.decode(V1DecisionCriteriaContent.self, forKey: .payload))
        case .codeExplanation:
            self = .codeExplanation(try container.decode(V1CodeExplanationContent.self, forKey: .payload))
        case .processGuide:
            self = .processGuide(try container.decode(V1ProcessGuideContent.self, forKey: .payload))
        case .cardSorting:
            self = .cardSorting(try container.decode(V1CardSortingContent.self, forKey: .payload))
        case .matching:
            self = .matching(try container.decode(V1MatchingContent.self, forKey: .payload))
        case .choiceWithReason:
            self = .choiceWithReason(try container.decode(V1ChoiceWithReasonContent.self, forKey: .payload))
        case .fillInBlank:
            self = .fillInBlank(try container.decode(V1FillInBlankContent.self, forKey: .payload))
        case .codeAssembly:
            self = .codeAssembly(try container.decode(V1CodeAssemblyContent.self, forKey: .payload))
        case .freeResponse:
            self = .freeResponse(try container.decode(V1FreeResponseContent.self, forKey: .payload))
        case .recallCheck:
            self = .recallCheck(try container.decode(V1RecallCheckContent.self, forKey: .payload))
        case .semanticChunkReading:
            self = .semanticChunkReading(
                try container.decode(V1SemanticChunkReadingContent.self, forKey: .payload)
            )
        case .learningClosure:
            self = .learningClosure(
                try container.decode(V1LearningClosureContent.self, forKey: .payload)
            )
        case .knowledgeLink:
            self = .knowledgeLink(try container.decode(V1KnowledgeLinkSectionContent.self, forKey: .payload))
        case .enrichmentTask:
            self = .enrichmentTask(try container.decode(V1EnrichmentTaskContent.self, forKey: .payload))
        case .personalKnowledgePromotion:
            self = .personalKnowledgePromotion(
                try container.decode(V1PersonalKnowledgePromotionContent.self, forKey: .payload)
            )
        case .personalKnowledgeRelation:
            self = .personalKnowledgeRelation(
                try container.decode(V1PersonalKnowledgeRelationSectionContent.self, forKey: .payload)
            )
        case .knowledgeChangeSummary:
            self = .knowledgeChangeSummary(
                try container.decode(V1KnowledgeChangeSummaryContent.self, forKey: .payload)
            )
        }
    }

    /// enum → JSON 변환.
    /// 현재 case의 tag와 associated payload를 공통 envelope에 함께 기록한다.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tag.rawValue, forKey: .tag)

        switch self {
        case let .learningCompass(payload): try container.encode(payload, forKey: .payload)
        case let .situation(payload): try container.encode(payload, forKey: .payload)
        case let .comparison(payload): try container.encode(payload, forKey: .payload)
        case let .definition(payload): try container.encode(payload, forKey: .payload)
        case let .decisionCriteria(payload): try container.encode(payload, forKey: .payload)
        case let .codeExplanation(payload): try container.encode(payload, forKey: .payload)
        case let .processGuide(payload): try container.encode(payload, forKey: .payload)
        case let .cardSorting(payload): try container.encode(payload, forKey: .payload)
        case let .matching(payload): try container.encode(payload, forKey: .payload)
        case let .choiceWithReason(payload): try container.encode(payload, forKey: .payload)
        case let .fillInBlank(payload): try container.encode(payload, forKey: .payload)
        case let .codeAssembly(payload): try container.encode(payload, forKey: .payload)
        case let .freeResponse(payload): try container.encode(payload, forKey: .payload)
        case let .recallCheck(payload): try container.encode(payload, forKey: .payload)
        case let .semanticChunkReading(payload): try container.encode(payload, forKey: .payload)
        case let .learningClosure(payload): try container.encode(payload, forKey: .payload)
        case let .knowledgeLink(payload): try container.encode(payload, forKey: .payload)
        case let .enrichmentTask(payload): try container.encode(payload, forKey: .payload)
        case let .personalKnowledgePromotion(payload): try container.encode(payload, forKey: .payload)
        case let .personalKnowledgeRelation(payload): try container.encode(payload, forKey: .payload)
        case let .knowledgeChangeSummary(payload): try container.encode(payload, forKey: .payload)
        }
    }
}

/// schema vocabulary에 없는 tag를 발견했을 때 tag 값과 JSON 경로를 보존하는 오류.
/// 이후 `ContentResourceDecoder`가 콘텐츠 작성자가 읽기 쉬운 리소스 오류로 변환한다.
struct V1UnsupportedLearningSectionTagError: Error, Equatable, Sendable, CustomStringConvertible {
    let tag: String
    let codingPath: [String]

    var description: String {
        "Unsupported learning section tag '\(tag)' at \(codingPath.joined(separator: "."))"
    }
}

// MARK: - Reading and observation payloads

/// 페이지 시작에서 이전 연결·핵심 질문·첫 예상·확신·완료 증거를 한곳에 둔다.
struct V1LearningCompassContent: Codable, Equatable, Sendable {
    let previousConnection: String
    let coreQuestion: String
    let firstPredictionPrompt: String
    let confidencePrompt: String
    let completionEvidence: [String]
}

/// 판단할 상황·자료와 첫 질문을 제시한다.
struct V1SituationContent: Codable, Equatable, Sendable {
    let title: String
    let description: String
    let materials: [V1LabeledText]
    let firstQuestion: String
}

/// 동일한 기준으로 여러 항목을 관찰하고 차이를 찾게 한다.
struct V1ComparisonContent: Codable, Equatable, Sendable {
    let criterion: String
    let items: [V1ComparisonItem]
    let observationQuestion: String
}

/// 공용 Concept의 정의와 현재 section에서 다룰 범위를 제시한다.
struct V1DefinitionContent: Codable, Equatable, Sendable {
    let conceptID: KnowledgeConceptID
    let title: String
    let definition: String
    let scope: String
}

/// 판단 질문의 순서와 주의점을 명시한다.
struct V1DecisionCriteriaContent: Codable, Equatable, Sendable {
    let questions: [String]
    let sequence: [String]
    let caution: String
}

/// 코드, 읽을 초점, 줄별 의미와 학습 범위를 함께 제공한다.
struct V1CodeExplanationContent: Codable, Equatable, Sendable {
    let code: String
    let language: String
    let focus: [String]
    let lineMeanings: [String]
    let outOfScope: [String]
    let displayTiming: String?
}

/// 순서 있는 사고·작업 절차와 완료 상태를 설명한다.
struct V1ProcessGuideContent: Codable, Equatable, Sendable {
    let steps: [V1ProcessStep]
    let completionDescription: String
}

// MARK: - Learner work payloads

/// 카드를 group으로 분류하며 개념 경계를 판단하게 한다.
struct V1CardSortingContent: Codable, Equatable, Sendable {
    let cards: [V1LearningContentItem]
    let groups: [V1LearningContentItem]
    let interaction: String
    let completionCriteria: [String]
    let feedbackCriteria: [String]
}

/// 좌우 항목을 규칙에 따라 대응시키게 한다.
struct V1MatchingContent: Codable, Equatable, Sendable {
    let leftItems: [V1LearningContentItem]
    let rightItems: [V1LearningContentItem]
    let rule: String
    let completionCriteria: [String]
}

/// 선택뿐 아니라 그 선택의 이유까지 입력하게 한다.
struct V1ChoiceWithReasonContent: Codable, Equatable, Sendable {
    let questions: [V1ChoiceQuestion]
    let reasonPrompt: String
    let feedbackCriteria: [String]
}

/// template의 빈칸을 정해진 후보로 완성하게 한다.
struct V1FillInBlankContent: Codable, Equatable, Sendable {
    let template: String
    let blanks: [V1FillInBlankItem]
    let completionCriteria: [String]
}

/// 고정된 코드와 조각을 조립해 선언을 완성하게 한다.
struct V1CodeAssemblyContent: Codable, Equatable, Sendable {
    let starterCode: String
    let pieces: [V1LearningContentItem]
    let fixedParts: [String]
    let completionCriteria: [String]
}

/// 정답 형태를 제한하지 않고, 요구 근거와 입력 형식만 계약한다.
struct V1FreeResponseContent: Codable, Equatable, Sendable {
    let prompt: String
    let inputFormat: String
    let requiredEvidence: [String]
    let exampleAfterSubmission: String
}

/// 학습 전후의 회상 내용을 비교할 수 있도록 질문과 기록 field를 정한다.
struct V1RecallCheckContent: Codable, Equatable, Sendable {
    let questions: [String]
    let comparisonTarget: String
    let recordFields: [String]
}

/// 성찰과 완료 판단을 한 흐름에서 기록해 페이지의 학습 루프를 닫는다.
struct V1LearningClosureContent: Codable, Equatable, Sendable {
    let firstPredictionReference: String
    let finalExplanationPrompt: String
    let confidenceChangePrompt: String
    let changedCriterionPrompt: String
    let nextUsePrompt: String
    let completionQuestion: String
    let requiredEvidence: [String]
    let retryCondition: String
}

/// 물리적으로 떨어진 코드 요소를 같은 책임과 흐름의 의미 Chunk로 묶게 한다.
struct V1SemanticChunkReadingContent: Codable, Equatable, Sendable {
    let code: String
    let language: String
    let lensQuestions: [String]
    let elements: [V1LearningContentItem]
    let selectionPrompt: String
    let chunkNamePrompt: String
    let flowPrompt: String
    let boundaryPrompt: String
    let changePrompt: String
    let completionEvidence: [String]
}

// MARK: - Shared and branching payloads

/// section 안에서 사용할 Page → Concept 연결들을 묶는다.
struct V1KnowledgeLinkSectionContent: Codable, Equatable, Sendable {
    let links: [V1LearningKnowledgeLink]
}

/// 핵심 완료 뒤 사용자가 선택해 펼치는 확장 과제.
struct V1EnrichmentTaskContent: Codable, Equatable, Sendable {
    let title: String
    let guidance: String
    let materials: [V1LabeledText]
    let prompt: String
    let conceptIDs: [KnowledgeConceptID]
}

/// 활동 근거를 검토 가능한 개인 지식 후보로 승격하는 흐름을 정의한다.
struct V1PersonalKnowledgePromotionContent: Codable, Equatable, Sendable {
    let evidenceActivityIDs: [LearningActivityID]
    let conceptIDs: [KnowledgeConceptID]
    let candidateKind: KnowledgePersonalizationCandidate.Kind
    let editableDraft: String
    let confirmationQuestion: String
    let savedFields: [String]
    let cancellationResult: String
}

/// 두 Concept 집합 사이의 개인 연결 문장과 근거를 작성하게 한다.
struct V1PersonalKnowledgeRelationSectionContent: Codable, Equatable, Sendable {
    let sourceConceptIDs: [KnowledgeConceptID]
    let targetConceptIDs: [KnowledgeConceptID]
    let draftStatement: String
    let reasonPrompt: String
    let evidenceActivityIDs: [LearningActivityID]
    let confirmationQuestion: String
}

/// 확정·대기 중인 개인 지식 변화와 다음 사용 시점을 요약한다.
struct V1KnowledgeChangeSummaryContent: Codable, Equatable, Sendable {
    let confirmedExpressions: String
    let confirmedRelations: String
    let pendingCandidates: String
    let nextUseSuggestion: String
    let emptyState: String
}

// MARK: - Shared payload values

/// 선택적 label과 본문을 여러 payload에서 재사용하는 값.
struct V1LabeledText: Codable, Equatable, Sendable {
    let label: String?
    let text: String
}

/// 비교 화면의 한 항목과 세부 근거.
struct V1ComparisonItem: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let body: String
    let details: [V1LabeledText]
}

/// `V1ProcessGuideContent`에서 사용하는 순서 있는 한 단계.
struct V1ProcessStep: Codable, Equatable, Sendable {
    let order: Int
    let title: String
    let question: String
}

/// 상호작용 payload에서 재사용하는 stable local item과 표시 문구.
struct V1LearningContentItem: Codable, Equatable, Sendable {
    let id: String
    let text: String
}

/// 하나의 선택 질문과 선택지 목록.
struct V1ChoiceQuestion: Codable, Equatable, Sendable {
    let id: String
    let prompt: String
    let options: [V1LearningContentItem]
}

/// template 빈칸의 local ID, 안내 문구와 후보 값.
struct V1FillInBlankItem: Codable, Equatable, Sendable {
    let id: String
    let placeholder: String
    let options: [String]
}

// MARK: - 다음 읽기: ConriculumTests/Content/LearningSectionContentTests.swift
