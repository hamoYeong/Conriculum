import SwiftUI

struct KnowledgeGraphView: View {
    let snapshot: KnowledgeSystemSnapshot
    let concepts: [KnowledgeSystemSnapshot.ConceptItem]
    let baseRelations: [KnowledgeRelation]
    let personalRelations: [PersonalKnowledgeRelation]
    let selectedConceptIDs: [KnowledgeConceptID]
    let onSelect: (KnowledgeConceptID) -> Void
    let onCompare: (KnowledgeConceptID) -> Void

    var body: some View {
        if concepts.isEmpty {
            ContentUnavailableView {
                Label("표시할 지식이 없습니다", systemImage: "magnifyingglass")
            } description: {
                Text("검색어나 선택한 분류를 바꾸어 보세요.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { geometry in
                let layout = KnowledgeGraphLayout(
                    concepts: concepts,
                    collections: snapshot.collections,
                    relations: baseRelations,
                    availableSize: geometry.size
                )

                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        graphEdges(layout: layout)

                        ForEach(concepts) { item in
                            if let position = layout.position(for: item.id) {
                                KnowledgeGraphNode(
                                    item: item,
                                    collectionTitle: snapshot.collection(
                                        id: item.collectionID
                                    )?.title ?? "지식",
                                    tint: collectionTint(for: item.collectionID),
                                    isSelected: selectedConceptIDs.contains(
                                        item.id
                                    ),
                                    canCompare: !selectedConceptIDs.isEmpty
                                        && !selectedConceptIDs.contains(item.id),
                                    onSelect: { onSelect(item.id) },
                                    onCompare: { onCompare(item.id) }
                                )
                                .frame(
                                    width: KnowledgeGraphLayout.nodeSize.width,
                                    height: KnowledgeGraphLayout.nodeSize.height
                                )
                                .position(position)
                                .zIndex(
                                    selectedConceptIDs.contains(item.id) ? 2 : 1
                                )
                            }
                        }
                    }
                    .frame(
                        width: layout.canvasSize.width,
                        height: layout.canvasSize.height
                    )
                }
                .defaultScrollAnchor(.center)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
            }
            .overlay(alignment: .bottomLeading) {
                graphLegend
                    .padding(14)
            }
            .accessibilityLabel("지식 연결망")
        }
    }

    private func graphEdges(
        layout: KnowledgeGraphLayout
    ) -> some View {
        Canvas { context, _ in
            for relation in baseRelations {
                guard let source = layout.position(
                    for: relation.sourceConceptID
                ), let target = layout.position(
                    for: relation.targetConceptID
                ) else { continue }

                drawDirectedEdge(
                    from: source,
                    to: target,
                    color: KnowledgeGraphPresentation.color(
                        for: relation.kind
                    ).opacity(0.48),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round),
                    context: &context
                )
            }

            for relation in personalRelations {
                guard let source = layout.position(
                    for: relation.sourceConceptID
                ), let target = layout.position(
                    for: relation.targetConceptID
                ) else { continue }

                drawDirectedEdge(
                    from: source,
                    to: target,
                    color: Color.purple.opacity(0.72),
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round,
                        dash: [6, 5]
                    ),
                    context: &context
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func drawDirectedEdge(
        from source: CGPoint,
        to target: CGPoint,
        color: Color,
        style: StrokeStyle,
        context: inout GraphicsContext
    ) {
        let vector = CGVector(
            dx: target.x - source.x,
            dy: target.y - source.y
        )
        let length = max(hypot(vector.dx, vector.dy), 1)
        let unit = CGVector(
            dx: vector.dx / length,
            dy: vector.dy / length
        )
        let inset = nodeBoundaryDistance(along: unit) + 4
        guard length > inset * 2 else { return }
        let start = CGPoint(
            x: source.x + unit.dx * inset,
            y: source.y + unit.dy * inset
        )
        let end = CGPoint(
            x: target.x - unit.dx * inset,
            y: target.y - unit.dy * inset
        )

        var line = Path()
        line.move(to: start)
        line.addLine(to: end)
        context.stroke(line, with: .color(color), style: style)

        let arrowLength: CGFloat = 8
        let normal = CGVector(dx: -unit.dy, dy: unit.dx)
        var arrow = Path()
        arrow.move(to: end)
        arrow.addLine(to: CGPoint(
            x: end.x - unit.dx * arrowLength + normal.dx * 4,
            y: end.y - unit.dy * arrowLength + normal.dy * 4
        ))
        arrow.move(to: end)
        arrow.addLine(to: CGPoint(
            x: end.x - unit.dx * arrowLength - normal.dx * 4,
            y: end.y - unit.dy * arrowLength - normal.dy * 4
        ))
        context.stroke(
            arrow,
            with: .color(color),
            style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round)
        )
    }

    private func nodeBoundaryDistance(
        along unit: CGVector
    ) -> CGFloat {
        let horizontalDistance = abs(unit.dx) > 0.000_1
            ? KnowledgeGraphLayout.nodeSize.width / 2 / abs(unit.dx)
            : .greatestFiniteMagnitude
        let verticalDistance = abs(unit.dy) > 0.000_1
            ? KnowledgeGraphLayout.nodeSize.height / 2 / abs(unit.dy)
            : .greatestFiniteMagnitude
        return min(horizontalDistance, verticalDistance)
    }

    private func collectionTint(
        for collectionID: KnowledgeCollectionID
    ) -> Color {
        let index = snapshot.collections.firstIndex {
            $0.id == collectionID
        } ?? 0
        return KnowledgeCollectionTint.color(for: index)
    }

    private var graphLegend: some View {
        HStack(spacing: 12) {
            Label("기본 연결", systemImage: "arrow.right")
            Label("나의 연결", systemImage: "line.diagonal")
                .foregroundStyle(.purple)
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

private struct KnowledgeGraphNode: View {
    let item: KnowledgeSystemSnapshot.ConceptItem
    let collectionTitle: String
    let tint: Color
    let isSelected: Bool
    let canCompare: Bool
    let onSelect: () -> Void
    let onCompare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button(action: onSelect) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.concept.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if item.latestRevision != nil {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.purple)
                            .accessibilityLabel("나의 표현 있음")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("개념 상세를 엽니다.")

            HStack(spacing: 5) {
                Text(collectionTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 2)

                Button(action: onCompare) {
                    Image(systemName: "rectangle.split.2x1")
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .disabled(!canCompare)
                .help(
                    canCompare
                        ? "현재 개념과 나란히 봅니다."
                        : "먼저 비교할 개념을 하나 열어 주세요."
                )
                .accessibilityLabel("\(item.concept.title) 나란히 보기")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected ? tint : tint.opacity(0.34),
                    lineWidth: isSelected ? 2.5 : 1.2
                )
        }
        .shadow(
            color: .black.opacity(isSelected ? 0.12 : 0.05),
            radius: isSelected ? 8 : 3,
            y: 2
        )
        .accessibilityElement(children: .contain)
    }
}

private enum KnowledgeGraphPresentation {
    static func color(for kind: KnowledgeRelationKind) -> Color {
        switch kind {
        case .prerequisite: .orange
        case .related: .secondary
        case .contrastsWith: .pink
        case .refines: .indigo
        case .appliesTo: .teal
        case .leadsTo: .blue
        }
    }
}
