import ComposableArchitecture

enum CompletionSelfAssessment: String, Equatable, Sendable {
    case ready
    case retry

    var title: String {
        switch self {
        case .ready: "근거를 들어 설명할 수 있음"
        case .retry: "다시 확인한 뒤 설명하기"
        }
    }
}

enum PersonalKnowledgeComponentAction: Equatable, Sendable {
    case expressionInspectorRequested([KnowledgeConceptID])
    case promotionReviewRequested(
        activityID: LearningActivityID,
        targetConceptID: KnowledgeConceptID,
        expression: String
    )
    case promotionCancelled(LearningActivityID)
    case relationConfirmed(
        activityID: LearningActivityID,
        sourceConceptID: KnowledgeConceptID,
        targetConceptID: KnowledgeConceptID,
        statement: String,
        reason: String,
        evidenceActivityID: LearningActivityID
    )
    case relationCancelled(LearningActivityID)
}

@Reducer
struct LearningComponentFeature {
    @ObservableState
    struct State: Equatable {
        var selectedLearningStateID: String?
        var completionAssessments: [
            LearningActivityID: CompletionSelfAssessment
        ] = [:]
    }

    enum Action: Equatable {
        case learningStateSelected(String?)
        case completionAssessmentChanged(
            activityID: LearningActivityID,
            assessment: CompletionSelfAssessment
        )
        case personalKnowledge(PersonalKnowledgeComponentAction)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case activityFieldsChanged(
            activityID: LearningActivityID,
            fields: [ActivityResponseField]
        )
        case personalKnowledge(PersonalKnowledgeComponentAction)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .learningStateSelected(stateID):
                state.selectedLearningStateID = stateID
                return .none

            case let .completionAssessmentChanged(activityID, assessment):
                state.completionAssessments[activityID] = assessment
                return .send(.delegate(.activityFieldsChanged(
                    activityID: activityID,
                    fields: [
                        ActivityResponseField(
                            key: LearningActivityFieldKey.completionAssessment,
                            values: [assessment.rawValue]
                        )
                    ]
                )))

            case let .personalKnowledge(action):
                return .send(.delegate(.personalKnowledge(action)))

            case .delegate:
                return .none
            }
        }
    }
}
