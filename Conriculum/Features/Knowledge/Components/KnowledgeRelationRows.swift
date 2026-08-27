import SwiftUI

/// 방향 있는 관계의 두 끝점을 표시하고, 탐색기에서는 각 끝점을 선택할 수 있게 한다.
struct KnowledgeRelationEndpoints: View {
    let sourceConceptID: KnowledgeConceptID
    let targetConceptID: KnowledgeConceptID
    let conceptIndex: KnowledgeConceptIndex
    var onConceptSelected: ((KnowledgeConceptID) -> Void)?

    var body: some View {
        if let onConceptSelected {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                endpointButton(
                    conceptID: sourceConceptID,
                    onConceptSelected: onConceptSelected
                )

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                endpointButton(
                    conceptID: targetConceptID,
                    onConceptSelected: onConceptSelected
                )
            }
            .accessibilityElement(children: .contain)
        } else {
            Text(conceptIndex.endpoints(
                sourceConceptID: sourceConceptID,
                targetConceptID: targetConceptID
            ))
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var accessibilityLabel: String {
        "\(conceptIndex.title(for: sourceConceptID))에서 "
            + "\(conceptIndex.title(for: targetConceptID))로 연결"
    }

    private func endpointButton(
        conceptID: KnowledgeConceptID,
        onConceptSelected: @escaping (KnowledgeConceptID) -> Void
    ) -> some View {
        Button(conceptIndex.title(for: conceptID)) {
            onConceptSelected(conceptID)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityHint("이 개념의 상세 내용을 봅니다.")
    }
}

/// Catalog가 제공하는 공용 관계 한 행.
struct KnowledgeBaseRelationRow: View {
    let relation: KnowledgeRelation
    let conceptIndex: KnowledgeConceptIndex
    var onConceptSelected: ((KnowledgeConceptID) -> Void)?
    var onCompareRequested: ((KnowledgeConceptID, KnowledgeConceptID) -> Void)?

    @ViewBuilder
    var body: some View {
        if hasInteractiveControls {
            styledRelationContent
                .accessibilityElement(children: .contain)
        } else {
            styledRelationContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private var styledRelationContent: some View {
        relationContent
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var relationContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                KnowledgeRelationEndpoints(
                    sourceConceptID: relation.sourceConceptID,
                    targetConceptID: relation.targetConceptID,
                    conceptIndex: conceptIndex,
                    onConceptSelected: onConceptSelected
                )
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

                compareButton
            }

            Text(relation.summary)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                KnowledgePresentation.title(for: relation.kind),
                systemImage: KnowledgePresentation.systemImage(for: relation.kind)
            )
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var compareButton: some View {
        if let onCompareRequested {
            Button {
                onCompareRequested(
                    relation.sourceConceptID,
                    relation.targetConceptID
                )
            } label: {
                Image(systemName: "rectangle.split.2x1")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("두 개념 나란히 보기")
            .accessibilityLabel(
                "\(conceptIndex.title(for: relation.sourceConceptID))와 "
                    + "\(conceptIndex.title(for: relation.targetConceptID)) 나란히 보기"
            )
        }
    }

    private var hasInteractiveControls: Bool {
        onConceptSelected != nil || onCompareRequested != nil
    }

    private var accessibilityLabel: String {
        let endpoints = conceptIndex.endpoints(
            sourceConceptID: relation.sourceConceptID,
            targetConceptID: relation.targetConceptID
        )
        return "\(endpoints). \(KnowledgePresentation.title(for: relation.kind)). "
            + relation.summary
    }
}

/// 학습자가 확인해 저장한 개인 관계 한 행.
struct KnowledgePersonalRelationRow: View {
    let relation: PersonalKnowledgeRelation
    let conceptIndex: KnowledgeConceptIndex
    var onConceptSelected: ((KnowledgeConceptID) -> Void)?
    var onCompareRequested: ((KnowledgeConceptID, KnowledgeConceptID) -> Void)?
    var onEditRequested: ((PersonalKnowledgeRelationID) -> Void)?

    @ViewBuilder
    var body: some View {
        if hasInteractiveControls {
            styledRelationContent
                .accessibilityElement(children: .contain)
        } else {
            styledRelationContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private var styledRelationContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(Color.purple.opacity(0.55))
                .frame(width: 3)
                .accessibilityHidden(true)

            relationContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var relationContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                KnowledgeRelationEndpoints(
                    sourceConceptID: relation.sourceConceptID,
                    targetConceptID: relation.targetConceptID,
                    conceptIndex: conceptIndex,
                    onConceptSelected: onConceptSelected
                )
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

                compareButton
                editButton
            }

            Text(relation.statement)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Label(relation.reason, systemImage: "quote.bubble")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var compareButton: some View {
        if let onCompareRequested {
            Button {
                onCompareRequested(
                    relation.sourceConceptID,
                    relation.targetConceptID
                )
            } label: {
                Image(systemName: "rectangle.split.2x1")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("두 개념 나란히 보기")
            .accessibilityLabel(
                "\(conceptIndex.title(for: relation.sourceConceptID))와 "
                    + "\(conceptIndex.title(for: relation.targetConceptID)) 나란히 보기"
            )
        }
    }

    @ViewBuilder
    private var editButton: some View {
        if let onEditRequested {
            Button("수정") {
                onEditRequested(relation.id)
            }
            .controlSize(.small)
            .accessibilityLabel("개인 지식 관계 수정")
        }
    }

    private var hasInteractiveControls: Bool {
        onConceptSelected != nil
            || onCompareRequested != nil
            || onEditRequested != nil
    }

    private var accessibilityLabel: String {
        let endpoints = conceptIndex.endpoints(
            sourceConceptID: relation.sourceConceptID,
            targetConceptID: relation.targetConceptID
        )
        return "나의 지식 연결. \(endpoints). \(relation.statement). "
            + relation.reason
    }
}
