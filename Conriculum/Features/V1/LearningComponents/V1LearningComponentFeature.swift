import ComposableArchitecture

enum V1CompletionSelfAssessment: String, Equatable, Sendable {
    case ready
    case retry

    var title: String {
        switch self {
        case .ready: "근거를 들어 설명할 수 있음"
        case .retry: "다시 확인한 뒤 설명하기"
        }
    }
}

enum V1PersonalKnowledgeComponentAction: Equatable, Sendable {
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
struct V1LearningComponentFeature {
    @ObservableState
    struct State: Equatable {}

    enum Action: Equatable {
        case personalKnowledge(V1PersonalKnowledgeComponentAction)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case personalKnowledge(V1PersonalKnowledgeComponentAction)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .personalKnowledge(action):
                return .send(.delegate(.personalKnowledge(action)))

            case .delegate:
                return .none
            }
        }
    }
}
