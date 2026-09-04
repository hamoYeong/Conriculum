import SwiftUI

struct KnowledgeConceptNames {
    private let titles: [KnowledgeConceptID: String]

    init(titles: [KnowledgeConceptID: String]) {
        self.titles = titles
    }

    init(catalog: KnowledgeCatalog) {
        titles = Dictionary(
            uniqueKeysWithValues: catalog.concepts.map { ($0.id, $0.title) }
        )
    }

    func title(for conceptID: KnowledgeConceptID) -> String {
        titles[conceptID] ?? "연결된 개념"
    }
}

struct KnowledgeLinkComponent: View {
    let content: KnowledgeLinkSectionContent
    let conceptNames: KnowledgeConceptNames

    var body: some View {
        LearningBlock(
            title: "함께 쓰는 지식",
            intent: .observe
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(content.links.enumerated()), id: \.offset) {
                    _,
                    link in
                    knowledgeLink(link)
                }
            }
        }
    }

    private func knowledgeLink(_ link: LearningKnowledgeLink) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol(for: link.role))
                .foregroundStyle(accent(for: link.role))
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(conceptNames.title(for: link.conceptID))
                        .font(.callout.weight(.semibold))

                    Text(title(for: link.role))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(link.usage)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let displayTiming = link.displayTiming {
                    Text(displayTiming)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(conceptNames.title(for: link.conceptID)). "
                + "\(title(for: link.role)). \(link.usage)"
        )
    }

    private func title(for role: KnowledgeLinkRole) -> String {
        switch role {
        case .primary: "직접 사용"
        case .supporting: "함께 참고"
        case .prerequisite: "먼저 필요한 지식"
        case .enrichment: "확장·심화 연결"
        }
    }

    private func symbol(for role: KnowledgeLinkRole) -> String {
        switch role {
        case .primary: "target"
        case .supporting: "link"
        case .prerequisite: "arrow.backward"
        case .enrichment: "sparkles"
        }
    }

    private func accent(for role: KnowledgeLinkRole) -> Color {
        switch role {
        case .primary: .blue
        case .supporting: .teal
        case .prerequisite: .orange
        case .enrichment: .purple
        }
    }
}

struct EnrichmentTaskComponent: View {
    let content: EnrichmentTaskContent
    let conceptNames: KnowledgeConceptNames
    @State private var isExpanded = false

    var body: some View {
        LearningBlock(
            title: "선택 학습",
            intent: .apply,
            role: .checkpoint
        ) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(content.title)
                            .font(.callout.weight(.semibold))
                        Text(content.guidance)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(
                        systemName: isExpanded
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                }
                .padding(12)
                .contentShape(Rectangle())
                .background(
                    Color.purple.opacity(isExpanded ? 0.10 : 0.05),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.purple.opacity(0.20), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(content.title)
            .accessibilityValue(isExpanded ? "펼쳐짐" : "접힘")
            .accessibilityHint(content.guidance)

            if isExpanded {
                if !content.materials.isEmpty {
                    LearningLabeledTextGrid(
                        items: content.materials,
                        accent: .purple
                    )
                }

                LearningCallout(
                    title: "더 깊게 생각하기",
                    text: content.prompt,
                    accent: .purple,
                    presentation: .emphasized
                )

                Text(
                    content.conceptIDs
                        .map { conceptNames.title(for: $0) }
                        .joined(separator: " · ")
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel(
                    "연결된 개념. "
                        + content.conceptIDs
                            .map { conceptNames.title(for: $0) }
                            .joined(separator: ", ")
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct PersonalKnowledgePromotionComponent: View {
    let content: PersonalKnowledgePromotionContent
    let activity: LearningActivityInput
    let conceptNames: KnowledgeConceptNames
    let onAction: (PersonalKnowledgeComponentAction) -> Void
    @State private var isConfirming = false

    var body: some View {
        LearningBlock(
            title: "나의 표현으로 다듬기",
            intent: .apply,
            role: .task
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Label("연결 지식", systemImage: "link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(
                    content.conceptIDs
                        .map { conceptNames.title(for: $0) }
                        .joined(separator: " · ")
                )
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            }

            LearningOptionGrid(
                title: "반영할 개념",
                options: content.conceptIDs.map {
                    LearningContentItem(
                        id: $0.rawValue,
                        text: conceptNames.title(for: $0)
                    )
                },
                selection: targetConceptRawSelection,
                accent: .purple,
                allowsEmptySelection: false
            )
            .accessibilityHint(
                "후보를 확인한 뒤 새 표현을 저장할 개념을 선택합니다."
            )

            TextEditor(
                text: activity.textBinding(
                    for: LearningActivityFieldKey.personalExpression,
                    default: content.editableDraft
                )
            )
            .frame(minHeight: 110)
            .padding(8)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .accessibilityLabel("개인 지식으로 반영할 나의 표현")
            .accessibilityHint(
                "기본 지식은 바꾸지 않고 나의 표현으로 저장할 문장을 편집합니다."
            )

            Text(content.confirmationQuestion)
                .font(.callout.weight(.semibold))

            ActivityCriteriaView(
                title: "반영하면 저장되는 내용",
                criteria: content.savedFields,
                accent: .purple
            )

            HStack {
                Button("이번에는 반영하지 않기") {
                    onAction(.promotionCancelled(activity.activityID))
                }
                .accessibilityHint("나의 지식에 저장하지 않고 학습을 계속합니다.")

                Spacer()

                Button("개념 상세에서 검토") {
                    isConfirming = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedTargetConceptID == nil)
                .accessibilityHint("저장 내용을 확인하는 대화상자를 엽니다.")
            }
            .focusSection()

            Text(content.cancellationResult)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ActivityDraftStatusView(activity: activity)
        }
        .confirmationDialog(
            content.confirmationQuestion,
            isPresented: $isConfirming
        ) {
            Button("개념 상세에서 최종 확인") {
                guard let targetConceptID = selectedTargetConceptID else {
                    return
                }
                let expression = candidateExpression
                activity.updating(valuesByKey: [
                    LearningActivityFieldKey.personalExpression: [expression],
                    LearningActivityFieldKey.personalizationTargetConceptID: [
                        targetConceptID.rawValue
                    ],
                ])
                onAction(.promotionReviewRequested(
                    activityID: activity.activityID,
                    targetConceptID: targetConceptID,
                    expression: expression
                ))
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("아직 개인 지식에 저장하지 않습니다. 개념 상세에서 대상, 내용과 근거를 확인한 뒤 저장합니다.")
        }
    }

    private var selectedTargetConceptID: KnowledgeConceptID? {
        let storedValue = activity.value(
            for: LearningActivityFieldKey.personalizationTargetConceptID
        )
        let storedID = storedValue.isEmpty
            ? nil
            : KnowledgeConceptID(rawValue: storedValue)
        return storedID.flatMap {
            content.conceptIDs.contains($0) ? $0 : nil
        } ?? content.conceptIDs.first
    }

    private var targetConceptSelection: Binding<KnowledgeConceptID?> {
        Binding(
            get: { selectedTargetConceptID },
            set: { conceptID in
                guard let conceptID,
                      content.conceptIDs.contains(conceptID)
                else { return }
                activity.updating(
                    key: LearningActivityFieldKey
                        .personalizationTargetConceptID,
                    values: [conceptID.rawValue]
                )
            }
        )
    }

    private var targetConceptRawSelection: Binding<String> {
        Binding(
            get: { targetConceptSelection.wrappedValue?.rawValue ?? "" },
            set: { rawValue in
                guard rawValue.isEmpty == false else { return }
                targetConceptSelection.wrappedValue = KnowledgeConceptID(
                    rawValue: rawValue
                )
            }
        )
    }

    private var candidateExpression: String {
        let storedExpression = activity.value(
            for: LearningActivityFieldKey.personalExpression
        )
        return storedExpression.isEmpty
            ? content.editableDraft
            : storedExpression
    }
}

struct PersonalKnowledgeRelationComponent: View {
    let content: PersonalKnowledgeRelationSectionContent
    let activity: LearningActivityInput
    let conceptNames: KnowledgeConceptNames
    let onAction: (PersonalKnowledgeComponentAction) -> Void
    @State private var isConfirming = false

    var body: some View {
        LearningBlock(
            title: "나의 연결 만들기",
            intent: .apply,
            role: .task
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    conceptPicker(
                        title: "출발 개념",
                        conceptIDs: content.sourceConceptIDs,
                        selection: sourceSelection
                    )
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    conceptPicker(
                        title: "연결할 개념",
                        conceptIDs: selectableTargetConceptIDs,
                        selection: targetSelection
                    )
                }
                VStack(spacing: 10) {
                    conceptPicker(
                        title: "출발 개념",
                        conceptIDs: content.sourceConceptIDs,
                        selection: sourceSelection
                    )
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    conceptPicker(
                        title: "연결할 개념",
                        conceptIDs: selectableTargetConceptIDs,
                        selection: targetSelection
                    )
                }
            }

            TextEditor(
                text: activity.textBinding(
                    for: LearningActivityFieldKey.relationStatement,
                    default: content.draftStatement
                )
            )
            .frame(minHeight: 100)
            .padding(8)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .accessibilityLabel("나의 지식 연결 문장")
            .accessibilityHint(
                "출발 개념과 연결할 개념의 관계를 문장으로 편집합니다."
            )

            TextField(
                content.reasonPrompt,
                text: activity.textBinding(for: LearningActivityFieldKey.reason),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("지식 연결 이유")
            .accessibilityHint("이 연결을 만든 이유를 입력합니다.")

            Label(
                "근거 활동 \(content.evidenceActivityIDs.count)개를 확인하고 첫 활동을 대표 근거로 저장합니다.",
                systemImage: "checkmark.square"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(content.confirmationQuestion)
                .font(.callout.weight(.semibold))

            HStack {
                Button("이번에는 연결하지 않기") {
                    onAction(.relationCancelled(activity.activityID))
                }
                .accessibilityHint("나의 지식 관계에 저장하지 않고 계속합니다.")

                Spacer()

                Button("개념 상세에서 검토") {
                    isConfirming = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    selectedSourceConceptID == nil
                        || selectedTargetConceptID == nil
                )
                .accessibilityHint("선택과 문장을 확인한 뒤 오른쪽 개념 상세를 엽니다.")
            }
            .focusSection()

            ActivityDraftStatusView(activity: activity)
        }
        .confirmationDialog(
            content.confirmationQuestion,
            isPresented: $isConfirming
        ) {
            Button("개념 상세에서 최종 확인") {
                let storedStatement = activity.value(
                    for: LearningActivityFieldKey.relationStatement
                )
                guard let sourceConceptID = selectedSourceConceptID,
                      let targetConceptID = selectedTargetConceptID,
                      let evidenceActivityID = content.evidenceActivityIDs.first
                else { return }
                onAction(.relationConfirmed(
                    activityID: activity.activityID,
                    sourceConceptID: sourceConceptID,
                    targetConceptID: targetConceptID,
                    statement: storedStatement.isEmpty
                        ? content.draftStatement
                        : storedStatement,
                    reason: activity.value(
                        for: LearningActivityFieldKey.reason
                    ),
                    evidenceActivityID: evidenceActivityID
                ))
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("아직 저장하지 않습니다. 개념 상세에서 관계와 근거를 확인한 뒤 저장합니다.")
        }
    }

    private var selectedSourceConceptID: KnowledgeConceptID? {
        selectedConceptID(
            fieldKey: LearningActivityFieldKey.relationSourceConceptID,
            allowedIDs: content.sourceConceptIDs
        )
    }

    private var selectableTargetConceptIDs: [KnowledgeConceptID] {
        content.targetConceptIDs.filter { $0 != selectedSourceConceptID }
    }

    private var selectedTargetConceptID: KnowledgeConceptID? {
        selectedConceptID(
            fieldKey: LearningActivityFieldKey.relationTargetConceptID,
            allowedIDs: selectableTargetConceptIDs
        )
    }

    private var sourceSelection: Binding<KnowledgeConceptID?> {
        Binding(
            get: { selectedSourceConceptID },
            set: { conceptID in
                guard let conceptID else { return }
                var updates = [
                    LearningActivityFieldKey.relationSourceConceptID: [
                        conceptID.rawValue
                    ]
                ]
                if selectedTargetConceptID == conceptID,
                   let replacement = content.targetConceptIDs.first(
                       where: { $0 != conceptID }
                   ) {
                    updates[
                        LearningActivityFieldKey.relationTargetConceptID
                    ] = [replacement.rawValue]
                }
                activity.updating(valuesByKey: updates)
            }
        )
    }

    private var targetSelection: Binding<KnowledgeConceptID?> {
        Binding(
            get: { selectedTargetConceptID },
            set: { conceptID in
                guard let conceptID else { return }
                activity.updating(
                    key: LearningActivityFieldKey.relationTargetConceptID,
                    values: [conceptID.rawValue]
                )
            }
        )
    }

    private func selectedConceptID(
        fieldKey: String,
        allowedIDs: [KnowledgeConceptID]
    ) -> KnowledgeConceptID? {
        let storedValue = activity.value(for: fieldKey)
        let storedID = storedValue.isEmpty
            ? nil
            : KnowledgeConceptID(rawValue: storedValue)
        return storedID.flatMap { allowedIDs.contains($0) ? $0 : nil }
            ?? allowedIDs.first
    }

    private func conceptPicker(
        title: String,
        conceptIDs: [KnowledgeConceptID],
        selection: Binding<KnowledgeConceptID?>
    ) -> some View {
        let rawSelection = Binding<String>(
            get: { selection.wrappedValue?.rawValue ?? "" },
            set: { rawValue in
                guard rawValue.isEmpty == false else { return }
                selection.wrappedValue = KnowledgeConceptID(
                    rawValue: rawValue
                )
            }
        )

        return VStack(alignment: .leading, spacing: 5) {
            LearningOptionGrid(
                title: title,
                options: conceptIDs.map {
                    LearningContentItem(
                        id: $0.rawValue,
                        text: conceptNames.title(for: $0)
                    )
                },
                selection: rawSelection,
                accent: .teal,
                allowsEmptySelection: false
            )
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

struct KnowledgeChangeSummaryComponent: View {
    let content: KnowledgeChangeSummaryContent
    let hasConfirmedChanges: Bool
    let hasPendingCandidates: Bool

    var body: some View {
        LearningBlock(
            title: "이번 학습으로 달라진 지식",
            intent: .reflect,
            role: .checkpoint
        ) {
            if !hasConfirmedChanges, !hasPendingCandidates {
                LearningCallout(
                    title: "아직 확인된 변화 없음",
                    text: content.emptyState,
                    accent: .secondary,
                    presentation: .emphasized
                )
            } else {
                if hasConfirmedChanges {
                    summaryRow(
                        title: "확인한 나의 표현",
                        text: content.confirmedExpressions
                    )
                    summaryRow(
                        title: "확인한 나의 연결",
                        text: content.confirmedRelations
                    )
                }

                if hasPendingCandidates {
                    summaryRow(
                        title: "확인 전 후보",
                        text: content.pendingCandidates
                    )
                }

                LearningCallout(
                    title: "다음에 다시 쓰기",
                    text: content.nextUseSuggestion,
                    accent: .green,
                    presentation: .emphasized
                )
            }
        }
    }

    private func summaryRow(
        title: String,
        text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LearningSupportLabel(title: title, accent: .teal)

            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(text)")
    }
}
