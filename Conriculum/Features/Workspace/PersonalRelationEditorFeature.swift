import ComposableArchitecture
import Foundation

struct PersonalRelationDraftRequest: Equatable, Sendable {
    let sourceConceptID: KnowledgeConceptID
    let targetConceptID: KnowledgeConceptID
    let statement: String
    let reason: String
    let evidenceActivityID: LearningActivityID
}

@Reducer
struct PersonalRelationEditorFeature {
    @ObservableState
    struct State: Equatable {
        let availableConcepts: [KnowledgeConcept]
        let allowedSourceConceptIDs: [KnowledgeConceptID]
        let allowedTargetConceptIDs: [KnowledgeConceptID]
        let originalRelation: PersonalKnowledgeRelation?
        let evidenceActivityID: LearningActivityID
        let reasonPrompt: String
        var sourceConceptID: KnowledgeConceptID
        var targetConceptID: KnowledgeConceptID
        var statement: String
        var reason: String
        var isSaving = false
        var validationMessage: String?
        var persistenceErrorMessage: String?

        init(
            request: PersonalRelationDraftRequest,
            contract: KnowledgeContextSnapshot.RelationCreationContract,
            availableConcepts: [KnowledgeConcept]
        ) {
            self.availableConcepts = availableConcepts
            allowedSourceConceptIDs = contract.sourceConceptIDs
            allowedTargetConceptIDs = contract.targetConceptIDs
            originalRelation = nil
            evidenceActivityID = request.evidenceActivityID
            reasonPrompt = contract.reasonPrompt
            sourceConceptID = request.sourceConceptID
            targetConceptID = request.targetConceptID
            statement = request.statement
            reason = request.reason
        }

        init(
            editing relation: PersonalKnowledgeRelation,
            availableConcepts: [KnowledgeConcept]
        ) {
            self.availableConcepts = availableConcepts
            allowedSourceConceptIDs = availableConcepts.map(\.id)
            allowedTargetConceptIDs = availableConcepts.map(\.id)
            originalRelation = relation
            evidenceActivityID = relation.evidenceActivityID
            reasonPrompt = "이 관계를 만든 이유를 나의 말로 설명합니다."
            sourceConceptID = relation.sourceConceptID
            targetConceptID = relation.targetConceptID
            statement = relation.statement
            reason = relation.reason
        }

        var sourceConcepts: [KnowledgeConcept] {
            concepts(for: allowedSourceConceptIDs)
        }

        var targetConcepts: [KnowledgeConcept] {
            concepts(for: allowedTargetConceptIDs).filter {
                $0.id != sourceConceptID
            }
        }

        var hasUnsavedChanges: Bool {
            guard let originalRelation else { return true }
            return sourceConceptID != originalRelation.sourceConceptID
                || targetConceptID != originalRelation.targetConceptID
                || normalized(statement) != normalized(
                    originalRelation.statement
                )
                || normalized(reason) != normalized(originalRelation.reason)
        }

        fileprivate var saveValidationError: PersonalRelationValidationError? {
            guard allowedSourceConceptIDs.contains(sourceConceptID),
                  availableConcepts.contains(where: {
                      $0.id == sourceConceptID
                  })
            else { return .invalidSource }
            guard allowedTargetConceptIDs.contains(targetConceptID),
                  availableConcepts.contains(where: {
                      $0.id == targetConceptID
                  })
            else { return .invalidTarget }
            guard sourceConceptID != targetConceptID else {
                return .sameConcept
            }
            guard !normalized(statement).isEmpty else {
                return .missingStatement
            }
            guard !normalized(reason).isEmpty else { return .missingReason }
            guard hasUnsavedChanges else { return .unchanged }
            return nil
        }

        fileprivate func relation(
            id: PersonalKnowledgeRelationID,
            createdAt: Date
        ) -> PersonalKnowledgeRelation {
            PersonalKnowledgeRelation(
                id: id,
                sourceConceptID: sourceConceptID,
                targetConceptID: targetConceptID,
                statement: normalized(statement),
                reason: normalized(reason),
                evidenceActivityID: evidenceActivityID,
                createdAt: createdAt
            )
        }

        private func concepts(
            for ids: [KnowledgeConceptID]
        ) -> [KnowledgeConcept] {
            let conceptsByID = Dictionary(
                uniqueKeysWithValues: availableConcepts.map { ($0.id, $0) }
            )
            return ids.compactMap { conceptsByID[$0] }
        }

        private func normalized(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    enum Action: Equatable {
        case sourceConceptChanged(KnowledgeConceptID)
        case targetConceptChanged(KnowledgeConceptID)
        case statementChanged(String)
        case reasonChanged(String)
        case saveButtonTapped
        case cancelButtonTapped
        case saveResponse(SaveResponse)
        case delegate(Delegate)
    }

    enum SaveResponse: Equatable, Sendable {
        case saved(PersonalKnowledgeRelation)
        case failed(String)
    }

    enum Delegate: Equatable {
        case cancelled
        case saved(PersonalKnowledgeRelation)
    }

    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid
    @Dependency(\.personalKnowledgeClient) var personalKnowledgeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .sourceConceptChanged(conceptID):
                guard state.allowedSourceConceptIDs.contains(conceptID) else {
                    return .none
                }
                state.sourceConceptID = conceptID
                if state.targetConceptID == conceptID,
                   let replacement = state.allowedTargetConceptIDs.first(
                       where: { $0 != conceptID }
                   ) {
                    state.targetConceptID = replacement
                }
                clearMessages(in: &state)
                return .none

            case let .targetConceptChanged(conceptID):
                guard state.allowedTargetConceptIDs.contains(conceptID),
                      conceptID != state.sourceConceptID
                else { return .none }
                state.targetConceptID = conceptID
                clearMessages(in: &state)
                return .none

            case let .statementChanged(statement):
                state.statement = statement
                clearMessages(in: &state)
                return .none

            case let .reasonChanged(reason):
                state.reason = reason
                clearMessages(in: &state)
                return .none

            case .saveButtonTapped:
                if let validationError = state.saveValidationError {
                    state.validationMessage = validationError.errorDescription
                    return .none
                }
                let relationID = state.originalRelation?.id
                    ?? PersonalKnowledgeRelationID(
                        rawValue: uuid().uuidString.lowercased()
                    )
                let relation = state.relation(
                    id: relationID,
                    createdAt: now
                )
                state.isSaving = true
                state.validationMessage = nil
                state.persistenceErrorMessage = nil

                return .run { send in
                    do {
                        try await personalKnowledgeClient.saveRelation(
                            relation
                        )
                        let relations = try await personalKnowledgeClient
                            .loadRelations(relation.sourceConceptID)
                        guard let storedRelation = relations.first(
                            where: { $0.id == relation.id }
                        ) else {
                            throw PersonalRelationReadBackError(
                                relationID: relation.id
                            )
                        }
                        await send(.saveResponse(.saved(storedRelation)))
                    } catch {
                        await send(.saveResponse(.failed(
                            error.localizedDescription
                        )))
                    }
                }
                .cancellable(
                    id: "PersonalRelationEditorFeature.save",
                    cancelInFlight: true
                )

            case .cancelButtonTapped:
                return .send(.delegate(.cancelled))

            case let .saveResponse(.saved(relation)):
                state.isSaving = false
                state.persistenceErrorMessage = nil
                return .send(.delegate(.saved(relation)))

            case let .saveResponse(.failed(message)):
                state.isSaving = false
                state.persistenceErrorMessage = message
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func clearMessages(in state: inout State) {
        state.validationMessage = nil
        state.persistenceErrorMessage = nil
    }
}

enum PersonalRelationValidationError: LocalizedError, Equatable {
    case invalidSource
    case invalidTarget
    case sameConcept
    case missingStatement
    case missingReason
    case unchanged

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            "출발 개념을 선택해 주세요."
        case .invalidTarget:
            "연결할 개념을 선택해 주세요."
        case .sameConcept:
            "서로 다른 두 개념을 선택해 주세요."
        case .missingStatement:
            "두 개념의 관계를 한 문장 이상 입력해 주세요."
        case .missingReason:
            "이 관계를 만든 이유를 입력해 주세요."
        case .unchanged:
            "저장할 관계 변경 내용이 없습니다."
        }
    }
}

private struct PersonalRelationReadBackError: LocalizedError {
    let relationID: PersonalKnowledgeRelationID

    var errorDescription: String? {
        "저장한 개인 지식 관계를 다시 확인하지 못했습니다: \(relationID.rawValue)"
    }
}
