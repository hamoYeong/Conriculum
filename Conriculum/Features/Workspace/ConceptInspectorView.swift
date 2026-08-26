import ComposableArchitecture
import SwiftUI

struct ConceptInspectorView: View {
    let store: StoreOf<ConceptInspectorFeature>

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
                    if let review = store.personalizationReview {
                        personalizationReviewBanner(review)
                    }
                    baseKnowledge
                    personalKnowledgeEditor
                    evidenceStatus
                    knowledgeRelations

                    if let message = store.validationMessage {
                        messageBanner(
                            title: "저장 내용을 확인해 주세요",
                            message: message,
                            systemImage: "exclamationmark.circle",
                            color: .orange
                        )
                    }

                    if let message = store.persistenceErrorMessage {
                        messageBanner(
                            title: "개인 표현을 저장하지 못했습니다",
                            message: message,
                            systemImage: "externaldrive.badge.exclamationmark",
                            color: .red
                        )
                    }
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            if store.relationEditor == nil {
                footer
            }
        }
        .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("개념 Inspector", systemImage: "sidebar.trailing")
                .font(.title2.weight(.semibold))
                .accessibilityHeading(.h1)

            Text(store.concept.title)
                .font(.title3.weight(.semibold))

            Text("현재 문맥 · \(store.sourcePageTitle)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let role = store.role {
                Label("현재 페이지 역할 · \(roleTitle(role))", systemImage: "scope")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func personalizationReviewBanner(
        _ review: KnowledgePersonalizationReview
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                labeledText(
                    title: "반영할 개념",
                    text: conceptTitle(review.targetConceptID),
                    systemImage: "scope"
                )

                labeledText(
                    title: "연결 지식",
                    text: review.candidate.conceptIDs
                        .map { conceptTitle($0) }
                        .joined(separator: " · "),
                    systemImage: "link"
                )

                labeledText(
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
        } label: {
            Label(
                "활동 응답 후보 · 저장 전",
                systemImage: "person.crop.circle.badge.questionmark"
            )
            .font(.headline)
            .accessibilityHeading(.h2)
        }
    }

    private var baseKnowledge: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.concept.definition)
                    .fixedSize(horizontal: false, vertical: true)

                if let usage = store.usage {
                    labeledText(
                        title: "이 페이지에서",
                        text: usage,
                        systemImage: "arrow.turn.down.right"
                    )
                }

                labeledText(
                    title: "핵심 질문",
                    text: store.concept.essentialQuestion,
                    systemImage: "questionmark.bubble"
                )

                if !store.concept.examples.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("기본 예시", systemImage: "list.bullet")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(store.concept.examples, id: \.self) { example in
                            Text("• \(example)")
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("기본 지식 · 변경되지 않음", systemImage: "book.closed")
                .font(.headline)
                .accessibilityHeading(.h2)
        }
    }

    private var personalKnowledgeEditor: some View {
        GroupBox {
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
                        }
                        .controlSize(.small)
                    }

                    if store.examples.isEmpty {
                        Text("필요할 때 내 사례를 추가할 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.examples) { example in
                        exampleEditor(example)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(
                store.personalizationReview != nil
                    ? "나의 표현 · 활동 후보에서 시작"
                    : store.latestRevision == nil
                        ? "나의 표현 · 새 Revision"
                        : "나의 표현 · 최신 Revision에서 시작",
                systemImage: "person.crop.circle"
            )
            .font(.headline)
            .accessibilityHeading(.h2)
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
                }
                .buttonStyle(.borderless)
                .help("이 예시 삭제")
                .accessibilityLabel("예시 삭제")
            }
        }
        .padding(10)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
    }

    private var evidenceStatus: some View {
        Group {
            if let evidenceActivityID = store.evidenceActivityID {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("저장 근거 활동")
                            .font(.caption.weight(.semibold))
                        Text(evidenceActivityID.rawValue)
                            .font(.caption.monospaced())
                    }
                } icon: {
                    Image(systemName: "checkmark.seal")
                }
                .foregroundStyle(.secondary)
            } else {
                messageBanner(
                    title: "이 문맥에서는 새 Revision을 저장할 수 없습니다",
                    message: "관련 학습 페이지에서 근거 활동을 남긴 뒤 편집해 주세요. 기존 기본 지식은 계속 확인할 수 있습니다.",
                    systemImage: "lock",
                    color: .orange
                )
            }
        }
    }

    private var knowledgeRelations: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                relationGroupTitle("기본 지식 연결", systemImage: "books.vertical")

                if store.relevantBaseRelations.isEmpty {
                    Text("이 개념에 직접 연결된 기본 catalog 관계가 없습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.relevantBaseRelations, id: \.id) { relation in
                        baseRelationCard(relation)
                    }
                }

                Divider()

                HStack {
                    relationGroupTitle(
                        "나의 지식 연결",
                        systemImage: "person.2"
                    )
                    Spacer()
                    Button {
                        store.send(.addRelationButtonTapped)
                    } label: {
                        Label("관계 추가", systemImage: "plus")
                    }
                    .controlSize(.small)
                    .disabled(!store.canCreateRelation)
                    .accessibilityHint(
                        "현재 페이지가 허용한 두 개념으로 개인 관계 draft를 만듭니다."
                    )
                }

                if store.relevantPersonalRelations.isEmpty {
                    Text("아직 확인해 저장한 개인 관계가 없습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(
                        store.relevantPersonalRelations,
                        id: \.id
                    ) { relation in
                        personalRelationCard(relation)
                    }
                }

                if !store.canCreateRelation {
                    Label(
                        "새 관계는 관계 활동이 있는 Page 07·08에서 만들 수 있습니다.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("개념 사이의 관계", systemImage: "link")
                .font(.headline)
                .accessibilityHeading(.h2)
        }
    }

    private func relationGroupTitle(
        _ title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.callout.weight(.semibold))
    }

    private func baseRelationCard(_ relation: KnowledgeRelation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(relationEndpoints(
                source: relation.sourceConceptID,
                target: relation.targetConceptID
            ))
            .font(.caption.weight(.semibold))
            Text(relation.summary)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Text(baseRelationKindTitle(relation.kind))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private func personalRelationCard(
        _ relation: PersonalKnowledgeRelation
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(relationEndpoints(
                    source: relation.sourceConceptID,
                    target: relation.targetConceptID
                ))
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("수정") {
                    store.send(.editRelationButtonTapped(relation.id))
                }
                .controlSize(.small)
            }

            Text(relation.statement)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Label(relation.reason, systemImage: "quote.bubble")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.purple.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }

    private func relationEndpoints(
        source: KnowledgeConceptID,
        target: KnowledgeConceptID
    ) -> String {
        "\(conceptTitle(source)) → \(conceptTitle(target))"
    }

    private func conceptTitle(_ id: KnowledgeConceptID) -> String {
        store.availableConcepts.first { $0.id == id }?.title ?? id.rawValue
    }

    private func baseRelationKindTitle(
        _ kind: KnowledgeRelationKind
    ) -> String {
        switch kind {
        case .prerequisite: "선행 관계"
        case .related: "관련 관계"
        case .contrastsWith: "대조 관계"
        case .refines: "구체화 관계"
        case .appliesTo: "적용 관계"
        case .leadsTo: "다음으로 이어지는 관계"
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(
                store.personalizationReview == nil
                    ? "취소"
                    : "후보 검토 닫기"
            ) {
                store.send(.cancelButtonTapped)
            }
            .keyboardShortcut(.cancelAction)
            .disabled(store.isSaving)

            Spacer()

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
                            ? "Revision 저장"
                            : "확인하고 Revision 저장"
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
        .background(.regularMaterial)
    }

    private func labeledText(
        title: String,
        text: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func messageBanner(
        title: String,
        message: String,
        systemImage: String,
        color: Color
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .foregroundStyle(color)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            color.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private func roleTitle(_ role: KnowledgeLinkRole) -> String {
        switch role {
        case .primary: "핵심"
        case .supporting: "보조"
        case .prerequisite: "선행"
        case .enrichment: "확장·심화"
        }
    }
}

#Preview("Concept Inspector · New Revision") {
    ConceptInspectorView(
        store: Store(
            initialState: ConceptInspectorPreviewData.newRevision
        ) {
            ConceptInspectorFeature()
        }
    )
    .frame(width: 380, height: 760)
}

#Preview("Concept Inspector · Existing Revision") {
    ConceptInspectorView(
        store: Store(
            initialState: ConceptInspectorPreviewData.existingRevision
        ) {
            ConceptInspectorFeature()
        }
    )
    .frame(width: 380, height: 760)
}

#Preview("Concept Inspector · Relation") {
    ConceptInspectorView(
        store: Store(
            initialState: ConceptInspectorPreviewData.relationEditor
        ) {
            ConceptInspectorFeature()
        }
    )
    .frame(width: 380, height: 760)
}

#Preview("Concept Inspector · Activity Candidate") {
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
