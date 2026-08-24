enum LearningSectionTag: String, Codable, CaseIterable, Hashable, Sendable {
    // Reading and observation
    case knowledgeRecall
    case situation
    case comparison
    case definition
    case decisionCriteria
    case codeExplanation
    case processGuide

    // Learner work
    case cardSorting
    case matching
    case choiceWithReason
    case fillInBlank
    case codeAssembly
    case freeResponse
    case recallCheck

    // Shared and branching
    case knowledgeLink
    case personalExpressionComparison
    case learningStateSelection
    case enrichmentTask
    case completionCheck
    case personalKnowledgePromotion
    case personalKnowledgeRelation
    case knowledgeChangeSummary
}

enum LearningSectionContent: Codable, Equatable, Sendable {
    case knowledgeRecall(KnowledgeRecallContent)
    case situation(SituationContent)
    case comparison(ComparisonContent)
    case definition(DefinitionContent)
    case decisionCriteria(DecisionCriteriaContent)
    case codeExplanation(CodeExplanationContent)
    case processGuide(ProcessGuideContent)
    case cardSorting(CardSortingContent)
    case matching(MatchingContent)
    case choiceWithReason(ChoiceWithReasonContent)
    case fillInBlank(FillInBlankContent)
    case codeAssembly(CodeAssemblyContent)
    case freeResponse(FreeResponseContent)
    case recallCheck(RecallCheckContent)
    case knowledgeLink(KnowledgeLinkSectionContent)
    case personalExpressionComparison(PersonalExpressionComparisonContent)
    case learningStateSelection(LearningStateSelectionContent)
    case enrichmentTask(EnrichmentTaskContent)
    case completionCheck(CompletionCheckContent)
    case personalKnowledgePromotion(PersonalKnowledgePromotionContent)
    case personalKnowledgeRelation(PersonalKnowledgeRelationSectionContent)
    case knowledgeChangeSummary(KnowledgeChangeSummaryContent)

    private enum CodingKeys: String, CodingKey {
        case tag
        case payload
    }

    var tag: LearningSectionTag {
        switch self {
        case .knowledgeRecall: .knowledgeRecall
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
        case .knowledgeLink: .knowledgeLink
        case .personalExpressionComparison: .personalExpressionComparison
        case .learningStateSelection: .learningStateSelection
        case .enrichmentTask: .enrichmentTask
        case .completionCheck: .completionCheck
        case .personalKnowledgePromotion: .personalKnowledgePromotion
        case .personalKnowledgeRelation: .personalKnowledgeRelation
        case .knowledgeChangeSummary: .knowledgeChangeSummary
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawTag = try container.decode(String.self, forKey: .tag)
        guard let tag = LearningSectionTag(rawValue: rawTag) else {
            throw UnsupportedLearningSectionTagError(
                tag: rawTag,
                codingPath: (decoder.codingPath + [CodingKeys.tag]).map(\.stringValue)
            )
        }

        switch tag {
        case .knowledgeRecall:
            self = .knowledgeRecall(try container.decode(KnowledgeRecallContent.self, forKey: .payload))
        case .situation:
            self = .situation(try container.decode(SituationContent.self, forKey: .payload))
        case .comparison:
            self = .comparison(try container.decode(ComparisonContent.self, forKey: .payload))
        case .definition:
            self = .definition(try container.decode(DefinitionContent.self, forKey: .payload))
        case .decisionCriteria:
            self = .decisionCriteria(try container.decode(DecisionCriteriaContent.self, forKey: .payload))
        case .codeExplanation:
            self = .codeExplanation(try container.decode(CodeExplanationContent.self, forKey: .payload))
        case .processGuide:
            self = .processGuide(try container.decode(ProcessGuideContent.self, forKey: .payload))
        case .cardSorting:
            self = .cardSorting(try container.decode(CardSortingContent.self, forKey: .payload))
        case .matching:
            self = .matching(try container.decode(MatchingContent.self, forKey: .payload))
        case .choiceWithReason:
            self = .choiceWithReason(try container.decode(ChoiceWithReasonContent.self, forKey: .payload))
        case .fillInBlank:
            self = .fillInBlank(try container.decode(FillInBlankContent.self, forKey: .payload))
        case .codeAssembly:
            self = .codeAssembly(try container.decode(CodeAssemblyContent.self, forKey: .payload))
        case .freeResponse:
            self = .freeResponse(try container.decode(FreeResponseContent.self, forKey: .payload))
        case .recallCheck:
            self = .recallCheck(try container.decode(RecallCheckContent.self, forKey: .payload))
        case .knowledgeLink:
            self = .knowledgeLink(try container.decode(KnowledgeLinkSectionContent.self, forKey: .payload))
        case .personalExpressionComparison:
            self = .personalExpressionComparison(
                try container.decode(PersonalExpressionComparisonContent.self, forKey: .payload)
            )
        case .learningStateSelection:
            self = .learningStateSelection(
                try container.decode(LearningStateSelectionContent.self, forKey: .payload)
            )
        case .enrichmentTask:
            self = .enrichmentTask(try container.decode(EnrichmentTaskContent.self, forKey: .payload))
        case .completionCheck:
            self = .completionCheck(try container.decode(CompletionCheckContent.self, forKey: .payload))
        case .personalKnowledgePromotion:
            self = .personalKnowledgePromotion(
                try container.decode(PersonalKnowledgePromotionContent.self, forKey: .payload)
            )
        case .personalKnowledgeRelation:
            self = .personalKnowledgeRelation(
                try container.decode(PersonalKnowledgeRelationSectionContent.self, forKey: .payload)
            )
        case .knowledgeChangeSummary:
            self = .knowledgeChangeSummary(
                try container.decode(KnowledgeChangeSummaryContent.self, forKey: .payload)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tag.rawValue, forKey: .tag)

        switch self {
        case let .knowledgeRecall(payload): try container.encode(payload, forKey: .payload)
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
        case let .knowledgeLink(payload): try container.encode(payload, forKey: .payload)
        case let .personalExpressionComparison(payload): try container.encode(payload, forKey: .payload)
        case let .learningStateSelection(payload): try container.encode(payload, forKey: .payload)
        case let .enrichmentTask(payload): try container.encode(payload, forKey: .payload)
        case let .completionCheck(payload): try container.encode(payload, forKey: .payload)
        case let .personalKnowledgePromotion(payload): try container.encode(payload, forKey: .payload)
        case let .personalKnowledgeRelation(payload): try container.encode(payload, forKey: .payload)
        case let .knowledgeChangeSummary(payload): try container.encode(payload, forKey: .payload)
        }
    }
}

struct UnsupportedLearningSectionTagError: Error, Equatable, Sendable, CustomStringConvertible {
    let tag: String
    let codingPath: [String]

    var description: String {
        "Unsupported learning section tag '\(tag)' at \(codingPath.joined(separator: "."))"
    }
}

// MARK: - Reading and observation payloads

struct KnowledgeRecallContent: Codable, Equatable, Sendable {
    let questions: [String]
    let memorySentence: String
    let connection: String
}

struct SituationContent: Codable, Equatable, Sendable {
    let title: String
    let description: String
    let materials: [LabeledText]
    let firstQuestion: String
}

struct ComparisonContent: Codable, Equatable, Sendable {
    let criterion: String
    let items: [ComparisonItem]
    let observationQuestion: String
}

struct DefinitionContent: Codable, Equatable, Sendable {
    let conceptID: KnowledgeConceptID
    let title: String
    let definition: String
    let scope: String
}

struct DecisionCriteriaContent: Codable, Equatable, Sendable {
    let questions: [String]
    let sequence: [String]
    let caution: String
}

struct CodeExplanationContent: Codable, Equatable, Sendable {
    let code: String
    let language: String
    let focus: [String]
    let lineMeanings: [String]
    let outOfScope: [String]
    let displayTiming: String?
}

struct ProcessGuideContent: Codable, Equatable, Sendable {
    let steps: [ProcessStep]
    let completionDescription: String
}

// MARK: - Learner work payloads

struct CardSortingContent: Codable, Equatable, Sendable {
    let cards: [LearningContentItem]
    let groups: [LearningContentItem]
    let interaction: String
    let completionCriteria: [String]
    let feedbackCriteria: [String]
}

struct MatchingContent: Codable, Equatable, Sendable {
    let leftItems: [LearningContentItem]
    let rightItems: [LearningContentItem]
    let rule: String
    let completionCriteria: [String]
}

struct ChoiceWithReasonContent: Codable, Equatable, Sendable {
    let questions: [ChoiceQuestion]
    let reasonPrompt: String
    let feedbackCriteria: [String]
}

struct FillInBlankContent: Codable, Equatable, Sendable {
    let template: String
    let blanks: [FillInBlankItem]
    let completionCriteria: [String]
}

struct CodeAssemblyContent: Codable, Equatable, Sendable {
    let starterCode: String
    let pieces: [LearningContentItem]
    let fixedParts: [String]
    let completionCriteria: [String]
}

struct FreeResponseContent: Codable, Equatable, Sendable {
    let prompt: String
    let inputFormat: String
    let requiredEvidence: [String]
    let exampleAfterSubmission: String
}

struct RecallCheckContent: Codable, Equatable, Sendable {
    let questions: [String]
    let comparisonTarget: String
    let recordFields: [String]
}

// MARK: - Shared and branching payloads

struct KnowledgeLinkSectionContent: Codable, Equatable, Sendable {
    let links: [LearningKnowledgeLink]
}

struct PersonalExpressionComparisonContent: Codable, Equatable, Sendable {
    let conceptIDs: [KnowledgeConceptID]
    let baseExpression: String
    let personalExpressionEmptyState: String
    let comparisonQuestion: String
    let inspectorLocation: String
}

struct LearningStateSelectionContent: Codable, Equatable, Sendable {
    let options: [LearningStateOption]
    let defaultOptionID: String?
}

struct EnrichmentTaskContent: Codable, Equatable, Sendable {
    let requiredStateID: String
    let materials: [LabeledText]
    let prompt: String
    let conceptIDs: [KnowledgeConceptID]
}

struct CompletionCheckContent: Codable, Equatable, Sendable {
    let question: String
    let requiredEvidence: [String]
    let retryCondition: String
}

struct PersonalKnowledgePromotionContent: Codable, Equatable, Sendable {
    let evidenceActivityIDs: [LearningActivityID]
    let conceptIDs: [KnowledgeConceptID]
    let candidateKind: KnowledgePersonalizationCandidate.Kind
    let editableDraft: String
    let confirmationQuestion: String
    let savedFields: [String]
    let cancellationResult: String
}

struct PersonalKnowledgeRelationSectionContent: Codable, Equatable, Sendable {
    let sourceConceptIDs: [KnowledgeConceptID]
    let targetConceptIDs: [KnowledgeConceptID]
    let draftStatement: String
    let reasonPrompt: String
    let evidenceActivityIDs: [LearningActivityID]
    let confirmationQuestion: String
}

struct KnowledgeChangeSummaryContent: Codable, Equatable, Sendable {
    let confirmedExpressions: String
    let confirmedRelations: String
    let pendingCandidates: String
    let nextUseSuggestion: String
    let emptyState: String
}

// MARK: - Shared payload values

struct LabeledText: Codable, Equatable, Sendable {
    let label: String?
    let text: String
}

struct ComparisonItem: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let body: String
    let details: [LabeledText]
}

struct ProcessStep: Codable, Equatable, Sendable {
    let order: Int
    let title: String
    let question: String
}

struct LearningContentItem: Codable, Equatable, Sendable {
    let id: String
    let text: String
}

struct ChoiceQuestion: Codable, Equatable, Sendable {
    let id: String
    let prompt: String
    let options: [LearningContentItem]
}

struct FillInBlankItem: Codable, Equatable, Sendable {
    let id: String
    let placeholder: String
    let options: [String]
}

struct LearningStateOption: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let guidance: String
}
