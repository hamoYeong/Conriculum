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
            systemImage: "point.3.filled.connected.trianglepath.dotted",
            accent: .blue
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
                    Label(displayTiming, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .textBackgroundColor).opacity(0.52),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
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

struct PersonalExpressionComparisonComponent: View {
    let content: PersonalExpressionComparisonContent
    let personalExpression: String?
    let conceptNames: KnowledgeConceptNames
    let onAction: (PersonalKnowledgeComponentAction) -> Void

    var body: some View {
        LearningBlock(
            title: "기본 지식과 나의 표현",
            systemImage: "rectangle.split.2x1",
            accent: .purple
        ) {
            Text(conceptNamesText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    expressionPanel(
                        title: "기본 지식",
                        text: content.baseExpression,
                        systemImage: "book.closed"
                    )
                    expressionPanel(
                        title: "나의 표현",
                        text: personalExpression
                            ?? content.personalExpressionEmptyState,
                        systemImage: "person.text.rectangle"
                    )
                }

                VStack(spacing: 12) {
                    expressionPanel(
                        title: "기본 지식",
                        text: content.baseExpression,
                        systemImage: "book.closed"
                    )
                    expressionPanel(
                        title: "나의 표현",
                        text: personalExpression
                            ?? content.personalExpressionEmptyState,
                        systemImage: "person.text.rectangle"
                    )
                }
            }

            LearningCallout(
                title: "비교 질문",
                text: content.comparisonQuestion,
                systemImage: "arrow.left.arrow.right",
                accent: .purple
            )

            Button("사이드바에서 나의 표현 보기") {
                onAction(.expressionInspectorRequested(content.conceptIDs))
            }
            .accessibilityHint(content.inspectorLocation)
        }
    }

    private var conceptNamesText: String {
        content.conceptIDs
            .map { conceptNames.title(for: $0) }
            .joined(separator: " · ")
    }

    private func expressionPanel(
        title: String,
        text: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))

            Text(text)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .textBackgroundColor).opacity(0.55),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(text)")
    }
}

struct LearningStateSelectionComponent: View {
    let content: LearningStateSelectionContent
    let selectedStateID: String?
    let onSelectionChanged: (String?) -> Void

    private var effectiveSelectionID: String? {
        selectedStateID ?? content.defaultOptionID
    }

    var body: some View {
        LearningBlock(
            title: "지금의 학습 상태",
            systemImage: "gauge.with.dots.needle.33percent",
            accent: .indigo
        ) {
            Text("현재 상태에 맞는 학습 경로를 선택할 수 있습니다.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(content.options, id: \.id) { option in
                    optionButton(option)
                }
            }
            .focusSection()

            if effectiveSelectionID != nil {
                Button("기본 학습으로 돌아가기") {
                    onSelectionChanged(nil)
                }
                .accessibilityHint(
                    "선택한 확장·심화 경로를 해제하고 기본 학습을 표시합니다."
                )
            }
        }
    }

    private func optionButton(_ option: LearningStateOption) -> some View {
        let isSelected = effectiveSelectionID == option.id

        return Button {
            onSelectionChanged(isSelected ? nil : option.id)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.callout.weight(.semibold))
                    Text(option.guidance)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(option.title)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
        .accessibilityHint(option.guidance)
    }
}

struct EnrichmentTaskComponent: View {
    let content: EnrichmentTaskContent
    let selectedStateID: String?
    let conceptNames: KnowledgeConceptNames

    var isVisible: Bool {
        selectedStateID == content.requiredStateID
    }

    var body: some View {
        if isVisible {
            LearningBlock(
                title: "확장·심화 과제",
                systemImage: "sparkles",
                accent: .purple
            ) {
                if !content.materials.isEmpty {
                    LearningLabeledTextGrid(
                        items: content.materials,
                        accent: .purple
                    )
                }

                LearningCallout(
                    title: "더 깊게 생각하기",
                    text: content.prompt,
                    systemImage: "brain.head.profile",
                    accent: .purple
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
            }
        }
    }
}

struct CompletionCheckComponent: View {
    let content: CompletionCheckContent
    let activityID: LearningActivityID
    let assessment: CompletionSelfAssessment?
    let onAssessmentChanged: (
        _ activityID: LearningActivityID,
        _ assessment: CompletionSelfAssessment
    ) -> Void

    var body: some View {
        LearningBlock(
            title: "완료 점검",
            systemImage: "checkmark.seal",
            accent: .green
        ) {
            Text(content.question)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    assessmentButton(.ready)
                    assessmentButton(.retry)
                }
                VStack(spacing: 10) {
                    assessmentButton(.ready)
                    assessmentButton(.retry)
                }
            }
            .focusSection()

            ActivityCriteriaView(
                title: "설명에 포함할 근거",
                criteria: content.requiredEvidence,
                systemImage: "quote.bubble",
                accent: .green
            )

            LearningCallout(
                title: "다시 확인할 때",
                text: content.retryCondition,
                systemImage: "arrow.counterclockwise",
                accent: .orange
            )
        }
    }

    private func assessmentButton(
        _ option: CompletionSelfAssessment
    ) -> some View {
        let isSelected = assessment == option

        return Button {
            onAssessmentChanged(activityID, option)
        } label: {
            Label(
                option.title,
                systemImage: isSelected
                    ? "checkmark.circle.fill"
                    : "circle"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(option.title)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
        .accessibilityHint("현재 페이지의 완료 상태로 선택합니다.")
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
            systemImage: "person.crop.circle.badge.checkmark",
            accent: .purple
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

            Picker("반영할 개념", selection: targetConceptSelection) {
                ForEach(content.conceptIDs, id: \.self) { conceptID in
                    Text(conceptNames.title(for: conceptID))
                        .tag(Optional(conceptID))
                }
            }
            .pickerStyle(.menu)
            .accessibilityHint(
                "후보를 확인한 뒤 새 Revision을 저장할 개념을 선택합니다."
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
                systemImage: "internaldrive",
                accent: .purple
            )

            HStack {
                Button("이번에는 반영하지 않기") {
                    onAction(.promotionCancelled(activity.activityID))
                }
                .accessibilityHint("나의 지식에 저장하지 않고 학습을 계속합니다.")

                Spacer()

                Button("Inspector에서 검토") {
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
            Button("Inspector에서 최종 확인") {
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
            Text("아직 개인 지식에 저장하지 않습니다. Inspector에서 대상, 내용과 근거를 확인한 뒤 저장합니다.")
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
            systemImage: "point.3.connected.trianglepath.dotted",
            accent: .teal
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

                Button("Inspector에서 검토") {
                    isConfirming = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    selectedSourceConceptID == nil
                        || selectedTargetConceptID == nil
                )
                .accessibilityHint("선택과 문장을 확인한 뒤 trailing Inspector를 엽니다.")
            }
            .focusSection()

            ActivityDraftStatusView(activity: activity)
        }
        .confirmationDialog(
            content.confirmationQuestion,
            isPresented: $isConfirming
        ) {
            Button("Inspector에서 최종 확인") {
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
            Text("아직 저장하지 않습니다. Inspector에서 관계와 근거를 확인한 뒤 저장합니다.")
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
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(conceptIDs, id: \.self) { conceptID in
                    Text(conceptNames.title(for: conceptID))
                        .tag(Optional(conceptID))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .textBackgroundColor).opacity(0.55),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
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
            systemImage: "sparkles",
            accent: .green
        ) {
            if !hasConfirmedChanges, !hasPendingCandidates {
                LearningCallout(
                    title: "아직 확인된 변화 없음",
                    text: content.emptyState,
                    systemImage: "tray",
                    accent: .secondary
                )
            } else {
                if hasConfirmedChanges {
                    summaryRow(
                        title: "확인한 나의 표현",
                        text: content.confirmedExpressions,
                        systemImage: "person.text.rectangle"
                    )
                    summaryRow(
                        title: "확인한 나의 연결",
                        text: content.confirmedRelations,
                        systemImage: "link"
                    )
                }

                if hasPendingCandidates {
                    summaryRow(
                        title: "확인 전 후보",
                        text: content.pendingCandidates,
                        systemImage: "clock.badge.questionmark"
                    )
                }

                LearningCallout(
                    title: "다음에 다시 쓰기",
                    text: content.nextUseSuggestion,
                    systemImage: "arrow.forward.circle",
                    accent: .green
                )
            }
        }
    }

    private func summaryRow(
        title: String,
        text: String,
        systemImage: String
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.green)
                .frame(width: 22)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .textBackgroundColor).opacity(0.55),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(text)")
    }
}
