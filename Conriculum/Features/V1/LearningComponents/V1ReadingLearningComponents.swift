import SwiftUI

struct V1SituationComponent: View {
    let content: V1SituationContent

    var body: some View {
        LearningBlock(
            title: "상황",
            intent: .context,
            role: .checkpoint
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
                V1LearningLabeledTextGrid(
                    items: content.materials,
                    accent: .indigo
                )
            }

            LearningCallout(
                title: "먼저 생각해 보기",
                text: content.firstQuestion,
                accent: .indigo,
                presentation: .emphasized
            )
        }
    }
}

struct V1ComparisonComponent: View {
    let content: V1ComparisonContent

    var body: some View {
        LearningBlock(
            title: "비교하며 관찰하기",
            intent: .observe
        ) {
            LearningCallout(
                title: "비교 기준",
                text: content.criterion,
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
                accent: .purple,
                presentation: .emphasized
            )
        }
    }

    private func comparisonItem(_ item: V1ComparisonItem) -> some View {
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
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct V1DefinitionComponent: View {
    let content: V1DefinitionContent

    var body: some View {
        LearningBlock(
            title: "핵심 개념",
            intent: .encode,
            role: .checkpoint
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
                accent: .green
            )
        }
    }
}

struct V1DecisionCriteriaComponent: View {
    let content: V1DecisionCriteriaContent

    var body: some View {
        LearningBlock(
            title: "판단 기준",
            intent: .decide,
            role: .checkpoint
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
                accent: .orange,
                presentation: .emphasized
            )
        }
    }
}

struct V1CodeExplanationComponent: View {
    let content: V1CodeExplanationContent

    var body: some View {
        LearningBlock(
            title: "코드로 확인하기",
            intent: .apply
        ) {
            SwiftCodeBlock(
                code: content.code,
                language: content.language,
                spokenLabel: "\(content.language) 코드"
            )

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
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("코드에서 눈여겨볼 부분")
                    .accessibilityValue(content.focus.joined(separator: ", "))
                    .accessibilityHint(
                        "가로로 스크롤하여 모든 코드 조각을 확인할 수 있습니다."
                    )
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

struct V1ProcessGuideComponent: View {
    let content: V1ProcessGuideContent

    var body: some View {
        LearningBlock(
            title: "학습 진행 순서",
            intent: .context,
            role: .checkpoint
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(content.steps.sorted(by: { $0.order < $1.order }), id: \.order) {
                    step in
                    LearningNumberedRow(
                        number: step.order,
                        title: step.title,
                        text: step.question,
                        accent: .indigo
                    )
                }
            }

            LearningCallout(
                title: "완료 기준",
                text: content.completionDescription,
                accent: .green,
                presentation: .emphasized
            )
        }
    }
}
