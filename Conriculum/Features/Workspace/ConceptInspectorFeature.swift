import ComposableArchitecture
import Foundation

@Reducer
struct ConceptInspectorFeature {
    @ObservableState
    struct State: Equatable {
        struct ExampleDraft: Equatable, Identifiable, Sendable {
            let id: PersonalExampleID
            var text: String
            var context: String

            nonisolated init(example: PersonalExample) {
                id = example.id
                text = example.text
                context = example.context ?? ""
            }

            nonisolated init(
                id: PersonalExampleID,
                text: String = "",
                context: String = ""
            ) {
                self.id = id
                self.text = text
                self.context = context
            }
        }

        let sourcePageTitle: String
        let concept: KnowledgeConcept
        let role: KnowledgeLinkRole?
        let usage: String?
        let latestRevision: PersonalConceptRevision?
        let evidenceActivityID: LearningActivityID?
        var personalTitle: String
        var explanation: String
        var examples: [ExampleDraft]
        var isSaving = false
        var validationMessage: String?
        var persistenceErrorMessage: String?

        init(
            sourcePageTitle: String,
            item: KnowledgeContextSnapshot.ConceptItem
        ) {
            self.sourcePageTitle = sourcePageTitle
            concept = item.concept
            role = item.role
            usage = item.usage
            latestRevision = item.personalRevision
            evidenceActivityID = item.revisionEvidenceActivityID
            personalTitle = item.personalRevision?.personalTitle ?? ""
            explanation = item.personalRevision?.explanation ?? ""
            examples = item.personalRevision?.examples.map(ExampleDraft.init)
                ?? []
        }

        var hasUnsavedChanges: Bool {
            normalizedPersonalTitle != normalized(
                latestRevision?.personalTitle ?? ""
            )
                || normalizedExplanation != normalized(
                    latestRevision?.explanation ?? ""
                )
                || normalizedExamples != (latestRevision?.examples ?? [])
        }

        fileprivate var saveValidationError: ConceptRevisionValidationError? {
            guard evidenceActivityID != nil else { return .missingEvidence }
            guard !normalizedExplanation.isEmpty else {
                return .missingExplanation
            }
            guard examples.allSatisfy({ draft in
                !normalized(draft.text).isEmpty
                    || normalized(draft.context).isEmpty
            }) else {
                return .incompleteExample
            }
            guard hasUnsavedChanges else { return .unchanged }
            return nil
        }

        fileprivate func revision(
            id: PersonalConceptRevisionID,
            createdAt: Date,
            evidenceActivityID: LearningActivityID
        ) -> PersonalConceptRevision {
            PersonalConceptRevision(
                id: id,
                conceptID: concept.id,
                personalTitle: normalizedPersonalTitle.isEmpty
                    ? nil
                    : normalizedPersonalTitle,
                explanation: normalizedExplanation,
                examples: normalizedExamples,
                previousRevisionID: latestRevision?.id,
                evidenceActivityID: evidenceActivityID,
                createdAt: createdAt
            )
        }

        private var normalizedPersonalTitle: String {
            normalized(personalTitle)
        }

        private var normalizedExplanation: String {
            normalized(explanation)
        }

        private var normalizedExamples: [PersonalExample] {
            examples.compactMap { draft in
                let text = normalized(draft.text)
                let context = normalized(draft.context)
                guard !text.isEmpty else { return nil }
                return PersonalExample(
                    id: draft.id,
                    text: text,
                    context: context.isEmpty ? nil : context
                )
            }
        }

        private func normalized(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    enum Action: Equatable {
        case personalTitleChanged(String)
        case explanationChanged(String)
        case addExampleButtonTapped
        case exampleTextChanged(id: PersonalExampleID, text: String)
        case exampleContextChanged(id: PersonalExampleID, context: String)
        case removeExampleButtonTapped(PersonalExampleID)
        case saveButtonTapped
        case cancelButtonTapped
        case saveResponse(SaveResponse)
        case delegate(Delegate)
    }

    enum SaveResponse: Equatable, Sendable {
        case saved(PersonalConceptRevision)
        case failed(String)
    }

    enum Delegate: Equatable {
        case cancelled
        case saved(PersonalConceptRevision)
    }

    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid
    @Dependency(\.personalKnowledgeClient) var personalKnowledgeClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .personalTitleChanged(title):
                state.personalTitle = title
                clearMessages(in: &state)
                return .none

            case let .explanationChanged(explanation):
                state.explanation = explanation
                clearMessages(in: &state)
                return .none

            case .addExampleButtonTapped:
                state.examples.append(State.ExampleDraft(
                    id: PersonalExampleID(
                        rawValue: uuid().uuidString.lowercased()
                    )
                ))
                clearMessages(in: &state)
                return .none

            case let .exampleTextChanged(id, text):
                guard let index = state.examples.firstIndex(
                    where: { $0.id == id }
                ) else { return .none }
                state.examples[index].text = text
                clearMessages(in: &state)
                return .none

            case let .exampleContextChanged(id, context):
                guard let index = state.examples.firstIndex(
                    where: { $0.id == id }
                ) else { return .none }
                state.examples[index].context = context
                clearMessages(in: &state)
                return .none

            case let .removeExampleButtonTapped(id):
                state.examples.removeAll { $0.id == id }
                clearMessages(in: &state)
                return .none

            case .saveButtonTapped:
                if let validationError = state.saveValidationError {
                    state.validationMessage = validationError.errorDescription
                    return .none
                }
                guard let evidenceActivityID = state.evidenceActivityID else {
                    return .none
                }

                let revision = state.revision(
                    id: PersonalConceptRevisionID(
                        rawValue: uuid().uuidString.lowercased()
                    ),
                    createdAt: now,
                    evidenceActivityID: evidenceActivityID
                )
                state.isSaving = true
                state.validationMessage = nil
                state.persistenceErrorMessage = nil

                return .run { send in
                    do {
                        try await personalKnowledgeClient.saveRevision(
                            revision
                        )
                        let revisions = try await personalKnowledgeClient
                            .loadRevisions(revision.conceptID)
                        guard let storedRevision = revisions.first(
                            where: { $0.id == revision.id }
                        ) else {
                            throw ConceptRevisionReadBackError(
                                revisionID: revision.id
                            )
                        }
                        await send(.saveResponse(.saved(storedRevision)))
                    } catch {
                        await send(.saveResponse(.failed(
                            error.localizedDescription
                        )))
                    }
                }
                .cancellable(
                    id: "ConceptInspectorFeature.saveRevision",
                    cancelInFlight: true
                )

            case .cancelButtonTapped:
                return .send(.delegate(.cancelled))

            case let .saveResponse(.saved(revision)):
                state.isSaving = false
                state.persistenceErrorMessage = nil
                return .send(.delegate(.saved(revision)))

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

enum ConceptRevisionValidationError: LocalizedError, Equatable {
    case missingEvidence
    case missingExplanation
    case incompleteExample
    case unchanged

    var errorDescription: String? {
        switch self {
        case .missingEvidence:
            "이 페이지에는 선택한 개념의 저장 근거 활동이 없습니다. 관련 학습 페이지에서 표현을 남겨 주세요."
        case .missingExplanation:
            "나의 설명을 한 문장 이상 입력해 주세요."
        case .incompleteExample:
            "맥락을 적은 예시에는 예시 내용도 입력해 주세요."
        case .unchanged:
            "저장할 변경 내용이 없습니다."
        }
    }
}

private struct ConceptRevisionReadBackError: LocalizedError {
    let revisionID: PersonalConceptRevisionID

    var errorDescription: String? {
        "저장한 개인 표현을 다시 확인하지 못했습니다: \(revisionID.rawValue)"
    }
}
