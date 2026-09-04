import ComposableArchitecture
import SwiftUI

struct ConceptInspectorView: View {
    let store: StoreOf<ConceptInspectorFeature>
    @State private var isEditingPersonalExpression = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let relationStore = store.scope(
                    state: \.relationEditor,
                    action: \.relationEditor
                ) {
                    PersonalRelationEditorView(store: relationStore)
                    baseKnowledge
                    knowledgeRelations
                } else {
                    modeBar

                    if let review = store.personalizationReview {
                        personalizationReviewBanner(review)
                        baseKnowledge
                        personalKnowledgeEditor
                        evidenceStatus
                    } else if isEditingPersonalExpression {
                        baseKnowledge
                        personalKnowledgeEditor
                        evidenceStatus
                    } else {
                        baseKnowledge
                        personalKnowledgeReadOnly
                    }
                    knowledgeRelations

                    if let message = store.validationMessage {
                        KnowledgeMessageBanner(
                            title: "저장 내용을 확인해 주세요",
                            message: message,
                            systemImage: "exclamationmark.circle",
                            accent: .orange
                        )
                    }

                    if let message = store.persistenceErrorMessage {
                        KnowledgeMessageBanner(
                            title: "개인 표현을 저장하지 못했습니다",
                            message: message,
                            systemImage: "externaldrive.badge.exclamationmark",
                            accent: .red
                        )
                    }
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            if store.relationEditor == nil,
               isEditingPersonalExpression
                || store.personalizationReview != nil {
                footer
            }
        }
        .onChange(of: store.concept.id) {
            isEditingPersonalExpression = false
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        KnowledgeConceptHeader(
            concept: store.concept,
            contextTitle: store.sourcePageTitle,
            role: store.role
        )
    }

    private func personalizationReviewBanner(
        _ review: KnowledgePersonalizationReview
    ) -> some View {
        KnowledgeSection(
            title: "활동 응답 후보 · 저장 전",
            systemImage: "person.crop.circle.badge.questionmark",
            accent: .orange,
            presentation: .surface
        ) {
            VStack(alignment: .leading, spacing: 12) {
                KnowledgeLabeledText(
                    title: "반영할 개념",
                    text: conceptTitle(review.targetConceptID),
                    systemImage: "scope"
                )

                KnowledgeLabeledText(
                    title: "연결 지식",
                    text: review.candidate.conceptIDs
                        .map { conceptTitle($0) }
                        .joined(separator: " · "),
                    systemImage: "link"
                )

                KnowledgeLabeledText(
                    title: "활동 응답에서 만든 후보",
                    text: review.candidate.draft,
                    systemImage: "quote.bubble"
                )

                Text(review.confirmationQuestion)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    Label("저장 예정 항목", systemImage: "internaldrive")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(
                        Array(review.savedFields.enumerated()),
                        id: \.offset
                    ) { _, field in
                        Label(field, systemImage: "checkmark")
                            .font(.caption)
                    }
                }

                Label(
                    "아직 개인 지식에는 저장되지 않았습니다.",
                    systemImage: "clock"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var baseKnowledge: some View {
        BaseKnowledgeSection(
            concept: store.concept,
            usage: store.usage,
            detailLevel: .contextual
        )
    }

    private var modeBar: some View {
        HStack(spacing: 8) {
            inspectorModeButton(
                title: "읽기·비교",
                systemImage: "book.pages",
                isSelected: !isEditingPersonalExpression
                    && store.personalizationReview == nil
            ) {
                isEditingPersonalExpression = false
            }

            inspectorModeButton(
                title: store.personalizationReview == nil
                    ? "내 표현 편집"
                    : "후보 검토",
                systemImage: store.personalizationReview == nil
                    ? "square.and.pencil"
                    : "person.crop.circle.badge.questionmark",
                isSelected: isEditingPersonalExpression
                    || store.personalizationReview != nil
            ) {
                isEditingPersonalExpression = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("개념 상세 모드")
    }

    private func inspectorModeButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    isSelected
                        ? Color.accentColor
                        : Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(
                        cornerRadius: 9,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var personalKnowledgeReadOnly: some View {
        KnowledgeSection(
            title: "나의 표현",
            systemImage: "person.crop.circle",
            accent: .purple,
            presentation: .surface
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let revision = store.latestRevision {
                    if let personalTitle = revision.personalTitle,
                       personalTitle.isEmpty == false {
                        KnowledgeLabeledText(
                            title: "나의 이름",
                            text: personalTitle,
                            systemImage: "tag"
                        )
                    }

                    KnowledgeLabeledText(
                        title: "나의 설명",
                        text: revision.explanation,
                        systemImage: "text.quote"
                    )

                    if revision.examples.isEmpty == false {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("나의 예시", systemImage: "list.bullet")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(revision.examples, id: \.id) { example in
                                Text(example.text)
                                    .font(.callout)
                                    .fixedSize(
                                        horizontal: false,
                                        vertical: true
                                    )
                            }
                        }
                    }
                } else {
                    Text("아직 확인해 저장한 나의 표현이 없습니다. 기본 지식을 읽은 뒤, 학습 활동의 근거가 생겼을 때만 새 표현을 기록할 수 있습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    isEditingPersonalExpression = true
                } label: {
                    Label(
                        store.latestRevision == nil
                            ? "내 표현 만들기"
                            : "내 표현 편집",
                        systemImage: "square.and.pencil"
                    )
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        Color.purple.opacity(0.10),
                        in: RoundedRectangle(
                            cornerRadius: 9,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(.plain)
                .disabled(store.evidenceActivityID == nil)
                .accessibilityHint(
                    store.evidenceActivityID == nil
                        ? "관련 학습 페이지에서 근거 활동을 먼저 남겨 주세요."
                        : "기본 지식은 유지하고 나의 표현만 편집합니다."
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var personalKnowledgeEditor: some View {
        KnowledgeSection(
            title: store.personalizationReview != nil
                ? "나의 표현 · 활동 후보에서 시작"
                : store.latestRevision == nil
                    ? "나의 표현 · 새 표현 기록"
                    : "나의 표현 · 최신 기록에서 시작",
            systemImage: "person.crop.circle",
            accent: .purple,
            presentation: .surface
        ) {
            VStack(alignment: .leading, spacing: 14) {
                TextField(
                    "나만의 이름 (선택)",
                    text: Binding(
                        get: { store.personalTitle },
                        set: { store.send(.personalTitleChanged($0)) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityHint("기본 개념명은 유지되고 나의 표현에만 저장됩니다.")

                VStack(alignment: .leading, spacing: 6) {
                    Text("나의 설명")
                        .font(.caption.weight(.semibold))
                    TextEditor(
                        text: Binding(
                            get: { store.explanation },
                            set: { store.send(.explanationChanged($0)) }
                        )
                    )
                    .frame(minHeight: 120)
                    .padding(7)
                    .background(
                        Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                Color(nsColor: .separatorColor),
                                lineWidth: 1
                            )
                    }
                    .accessibilityLabel("나의 설명")
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("나의 예시")
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Button {
                            store.send(.addExampleButtonTapped)
                        } label: {
                            Label("예시 추가", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    Color.purple.opacity(0.10),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    if store.examples.isEmpty {
                        Text("필요할 때 내 사례를 추가할 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.examples) { example in
                        exampleEditor(example)

                        if example.id != store.examples.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func exampleEditor(
        _ example: ConceptInspectorFeature.State.ExampleDraft
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            TextField(
                "예시 내용",
                text: Binding(
                    get: { example.text },
                    set: {
                        store.send(.exampleTextChanged(
                            id: example.id,
                            text: $0
                        ))
                    }
                )
            )
            .textFieldStyle(.roundedBorder)

            HStack {
                TextField(
                    "맥락 (선택)",
                    text: Binding(
                        get: { example.context },
                        set: {
                            store.send(.exampleContextChanged(
                                id: example.id,
                                context: $0
                            ))
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Button(role: .destructive) {
                    store.send(.removeExampleButtonTapped(example.id))
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .padding(7)
                        .background(Color.red.opacity(0.09), in: Circle())
                }
                .buttonStyle(.plain)
                .help("이 예시 삭제")
                .accessibilityLabel("예시 삭제")
            }
        }
        .padding(.vertical, 2)
    }

    private var evidenceStatus: some View {
        Group {
            if store.evidenceActivityID != nil {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("저장 근거")
                            .font(.caption.weight(.semibold))
                        Text("현재 페이지의 학습 활동과 연결됨")
                            .font(.caption)
                    }
                } icon: {
                    Image(systemName: "checkmark.seal")
                }
                .foregroundStyle(.secondary)
            } else {
                KnowledgeMessageBanner(
                    title: "이 문맥에서는 새 표현을 저장할 수 없습니다",
                    message: "관련 학습 페이지에서 근거 활동을 남긴 뒤 편집해 주세요. 기존 기본 지식은 계속 확인할 수 있습니다.",
                    systemImage: "lock",
                    accent: .orange
                )
            }
        }
    }

    private var knowledgeRelations: some View {
        KnowledgeRelationsSection(
            baseRelations: store.relevantBaseRelations,
            personalRelations: store.relevantPersonalRelations,
            conceptIndex: conceptIndex,
            canCreateRelation: store.canCreateRelation,
            relationCreationUnavailableMessage: store.canCreateRelation
                ? nil
                : "새 관계는 관계 만들기 활동이 제공되는 학습 페이지에서 기록할 수 있습니다.",
            onAddRelation: {
                store.send(.addRelationButtonTapped)
            },
            onEditPersonalRelation: { relationID in
                store.send(.editRelationButtonTapped(relationID))
            }
        )
    }

    private func conceptTitle(_ id: KnowledgeConceptID) -> String {
        conceptIndex.title(for: id)
    }

    private var conceptIndex: KnowledgeConceptIndex {
        KnowledgeConceptIndex(concepts: store.availableConcepts)
    }

    private var footer: some View {
        KnowledgeEditorActionLayout {
            Button(
                store.personalizationReview == nil
                    ? "취소"
                    : "후보 검토 닫기"
            ) {
                if store.personalizationReview == nil {
                    isEditingPersonalExpression = false
                } else {
                    store.send(.cancelButtonTapped)
                }
            }
            .keyboardShortcut(.cancelAction)
            .disabled(store.isSaving)

            Button {
                store.send(.saveButtonTapped)
            } label: {
                if store.isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("개인 표현 저장 중")
                } else {
                    Text(
                        store.personalizationReview == nil
                            ? "표현 저장"
                            : "확인하고 표현 저장"
                    )
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(store.isSaving || !store.hasUnsavedChanges)
            .accessibilityHint("저장 후 다시 읽은 결과로 지식 문맥을 갱신합니다.")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) { Divider() }
    }

}

/// 버튼 문구를 줄이지 않고, 공간이 부족하면 세로로 배치한다.
struct KnowledgeEditorActionLayout<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { content }
                .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .trailing, spacing: 10) { content }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

#Preview("개념 상세 · 새 표현") {
    ConceptInspectorView(
        store: Store(
            initialState: ConceptInspectorPreviewData.newRevision
        ) {
            ConceptInspectorFeature()
        }
    )
    .frame(width: 380, height: 760)
}

#Preview("개념 상세 · 저장된 표현") {
    ConceptInspectorView(
        store: Store(
            initialState: ConceptInspectorPreviewData.existingRevision
        ) {
            ConceptInspectorFeature()
        }
    )
    .frame(width: 380, height: 760)
}

#Preview("개념 상세 · 관계") {
    ConceptInspectorView(
        store: Store(
            initialState: ConceptInspectorPreviewData.relationEditor
        ) {
            ConceptInspectorFeature()
        }
    )
    .frame(width: 380, height: 760)
}

#Preview("개념 상세 · 활동 후보") {
    ConceptInspectorView(
        store: Store(
            initialState: ConceptInspectorPreviewData.activityCandidate
        ) {
            ConceptInspectorFeature()
        }
    )
    .frame(width: 380, height: 760)
}

private enum ConceptInspectorPreviewData {
    private static let concept = KnowledgeConcept(
        id: "concept-constants-variables",
        title: "상수와 변수",
        definition: "상수는 같은 이름에 다른 값을 넣지 않는 선언이고 변수는 필요할 때 다시 넣을 수 있는 선언이다.",
        essentialQuestion: "이 책임 안에서 같은 이름의 값이 바뀌어야 하는가?",
        judgmentQuestions: ["값 변경이 이 범위의 책임인가?"],
        examples: ["주문 번호는 let", "현재 재생 위치는 var"],
        misconceptions: []
    )
    private static let revision = PersonalConceptRevision(
        id: "revision-preview-constants",
        conceptID: concept.id,
        personalTitle: "변경 책임 약속",
        explanation: "현재 책임 안에서 같은 이름에 새 값을 넣을지를 판단한다.",
        examples: [
            PersonalExample(
                id: "example-preview-order",
                text: "주문 번호는 주문 중 바뀌지 않는다.",
                context: "주문 생성"
            )
        ],
        previousRevisionID: nil,
        evidenceActivityID: "activity-page05-choice",
        createdAt: Date(timeIntervalSince1970: 1_725_782_400)
    )

    static let newRevision = state(revision: nil)
    static let existingRevision = state(revision: revision)
    static let relationEditor: ConceptInspectorFeature.State = {
        let target = KnowledgeConcept(
            id: "concept-identifier-naming",
            title: "식별자와 이름 짓기",
            definition: "식별자는 값의 역할을 드러내는 이름이다.",
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
        var state = ConceptInspectorFeature.State(
            sourcePageTitle: "새로운 문제에 적용하고 돌아보기",
            item: KnowledgeContextSnapshot.ConceptItem(
                concept: concept,
                personalRevision: revision,
                revisionEvidenceActivityID: "activity-page08-free-response",
                role: .primary,
                usage: "변경 책임과 역할 이름을 함께 판단한다.",
                nearbyReason: nil
            ),
            availableConcepts: [concept, target],
            relationCreationContract: contract
        )
        state.relationEditor = PersonalRelationEditorFeature.State(
            request: PersonalRelationDraftRequest(
                sourceConceptID: concept.id,
                targetConceptID: target.id,
                statement: contract.draftStatement,
                reason: "선언과 이름이 같은 책임을 설명하기 때문이다.",
                evidenceActivityID: contract.evidenceActivityID
            ),
            contract: contract,
            availableConcepts: [concept, target]
        )
        return state
    }()
    static let activityCandidate: ConceptInspectorFeature.State = {
        let boundary = KnowledgeConcept(
            id: "concept-problem-boundary",
            title: "문제의 경계",
            definition: "해결이 책임질 대상과 밖에서 주어질 대상을 나눈다.",
            essentialQuestion: "이번 해결은 어디까지 책임지는가?",
            judgmentQuestions: [],
            examples: [],
            misconceptions: []
        )
        let review = KnowledgePersonalizationReview(
            candidate: KnowledgePersonalizationCandidate(
                id: "candidate-preview-constants",
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
            savedFields: ["나의 설명", "판단 경계", "근거 학습 활동", "수정 시각"]
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
    }()

    private static func state(
        revision: PersonalConceptRevision?
    ) -> ConceptInspectorFeature.State {
        ConceptInspectorFeature.State(
            sourcePageTitle: "변경 가능성으로 let과 var 판단하기",
            item: KnowledgeContextSnapshot.ConceptItem(
                concept: concept,
                personalRevision: revision,
                revisionEvidenceActivityID: "activity-page05-choice",
                role: .primary,
                usage: "현재 책임 안에서 값 변경이 필요한지 판단한다.",
                nearbyReason: nil
            )
        )
    }
}
