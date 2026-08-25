import SwiftUI

struct KnowledgeRecallComponent: View {
    let content: KnowledgeRecallContent

    var body: some View {
        LearningBlock(
            title: "기억 연결",
            systemImage: "arrow.counterclockwise",
            accent: .blue
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(content.questions.enumerated()), id: \.offset) {
                    index,
                    question in
                    LearningNumberedRow(
                        number: index + 1,
                        text: question,
                        accent: .blue
                    )
                }
            }

            LearningCallout(
                title: "기억할 문장",
                text: content.memorySentence,
                systemImage: "bookmark",
                accent: .blue
            )

            LearningCallout(
                title: "이번 학습과의 연결",
                text: content.connection,
                systemImage: "arrow.right",
                accent: .teal
            )
        }
    }
}

struct SituationComponent: View {
    let content: SituationContent

    var body: some View {
        LearningBlock(
            title: "상황",
            systemImage: "text.bubble",
            accent: .indigo
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(content.title)
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                Text(content.description)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !content.materials.isEmpty {
                LearningLabeledTextGrid(
                    items: content.materials,
                    accent: .indigo
                )
            }

            LearningCallout(
                title: "먼저 생각해 보기",
                text: content.firstQuestion,
                systemImage: "questionmark.bubble",
                accent: .indigo
            )
        }
    }
}

struct ComparisonComponent: View {
    let content: ComparisonContent

    var body: some View {
        LearningBlock(
            title: "비교하며 관찰하기",
            systemImage: "rectangle.split.2x1",
            accent: .purple
        ) {
            LearningCallout(
                title: "비교 기준",
                text: content.criterion,
                systemImage: "slider.horizontal.3",
                accent: .purple
            )

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: 210),
                        spacing: 12,
                        alignment: .top
                    )
                ],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(content.items, id: \.id) { item in
                    comparisonItem(item)
                }
            }

            LearningCallout(
                title: "관찰 질문",
                text: content.observationQuestion,
                systemImage: "eye",
                accent: .purple
            )
        }
    }

    private func comparisonItem(_ item: ComparisonItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)

            Text(item.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(item.details.enumerated()), id: \.offset) {
                _,
                detail in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let label = detail.label {
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.purple)
                    }
                    Text(detail.text)
                        .font(.callout)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .textBackgroundColor).opacity(0.55),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

struct DefinitionComponent: View {
    let content: DefinitionContent

    var body: some View {
        LearningBlock(
            title: "핵심 개념",
            systemImage: "book.closed",
            accent: .green
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(content.title)
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                Text(content.definition)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LearningCallout(
                title: "이번 범위",
                text: content.scope,
                systemImage: "scope",
                accent: .green
            )
        }
    }
}

struct DecisionCriteriaComponent: View {
    let content: DecisionCriteriaContent

    var body: some View {
        LearningBlock(
            title: "판단 기준",
            systemImage: "checklist",
            accent: .orange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("확인할 질문")
                    .font(.subheadline.weight(.semibold))

                ForEach(Array(content.questions.enumerated()), id: \.offset) {
                    index,
                    question in
                    LearningNumberedRow(
                        number: index + 1,
                        text: question,
                        accent: .orange
                    )
                }
            }

            if !content.sequence.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("판단 순서")
                        .font(.subheadline.weight(.semibold))

                    Text(content.sequence.joined(separator: "  →  "))
                        .font(.callout.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(
                            "판단 순서. "
                                + content.sequence.joined(separator: ", 다음으로 ")
                        )
                }
            }

            LearningCallout(
                title: "주의",
                text: content.caution,
                systemImage: "exclamationmark.triangle",
                accent: .orange
            )
        }
    }
}

struct CodeExplanationComponent: View {
    let content: CodeExplanationContent

    var body: some View {
        LearningBlock(
            title: "코드로 확인하기",
            systemImage: "chevron.left.forwardslash.chevron.right",
            accent: .cyan
        ) {
            ScrollView(.horizontal) {
                Text(verbatim: content.code)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(content.language) 코드")
            .accessibilityValue(content.code)
            .accessibilityHint("가로로 스크롤하여 긴 코드를 확인할 수 있습니다.")

            if !content.focus.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("눈여겨볼 부분")
                        .font(.subheadline.weight(.semibold))

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(content.focus, id: \.self) { focus in
                                Text(focus)
                                    .font(.callout.monospaced())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Color.cyan.opacity(0.10),
                                        in: Capsule()
                                    )
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }

            if !content.lineMeanings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("줄별 의미")
                        .font(.subheadline.weight(.semibold))

                    ForEach(
                        Array(content.lineMeanings.enumerated()),
                        id: \.offset
                    ) { index, meaning in
                        LearningNumberedRow(
                            number: index + 1,
                            text: meaning,
                            accent: .cyan
                        )
                    }
                }
            }

            if !content.outOfScope.isEmpty {
                LearningCallout(
                    title: "지금은 다루지 않기",
                    text: content.outOfScope.joined(separator: ", "),
                    systemImage: "clock",
                    accent: .secondary
                )
            }

            if let displayTiming = content.displayTiming {
                Text("표시 시점: \(displayTiming)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProcessGuideComponent: View {
    let content: ProcessGuideContent

    var body: some View {
        LearningBlock(
            title: "진행 순서",
            systemImage: "list.number",
            accent: .teal
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(content.steps.sorted(by: { $0.order < $1.order }), id: \.order) {
                    step in
                    LearningNumberedRow(
                        number: step.order,
                        title: step.title,
                        text: step.question,
                        accent: .teal
                    )
                }
            }

            LearningCallout(
                title: "완료 기준",
                text: content.completionDescription,
                systemImage: "checkmark.circle",
                accent: .green
            )
        }
    }
}
