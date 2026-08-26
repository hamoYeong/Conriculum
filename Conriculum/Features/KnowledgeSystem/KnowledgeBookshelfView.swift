import SwiftUI

enum KnowledgeCollectionTint {
    private static let colors: [Color] = [
        .blue,
        .teal,
        .indigo,
        .orange,
        .mint,
        .pink,
        .purple,
    ]

    static func color(for index: Int) -> Color {
        colors[index % colors.count]
    }
}

struct KnowledgeBookshelfView: View {
    let snapshot: KnowledgeSystemSnapshot
    let concepts: [KnowledgeSystemSnapshot.ConceptItem]
    let selectedConceptIDs: [KnowledgeConceptID]
    let onSelect: (KnowledgeConceptID) -> Void
    let onCompare: (KnowledgeConceptID) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                ForEach(visibleCollections) { collection in
                    let collectionConcepts = concepts.filter {
                        $0.collectionID == collection.id
                    }
                    let collectionIndex = snapshot.collections.firstIndex {
                        $0.id == collection.id
                    } ?? 0

                    KnowledgeBookshelfSection(
                        collection: collection,
                        concepts: collectionConcepts,
                        tint: KnowledgeCollectionTint.color(
                            for: collectionIndex
                        ),
                        selectedConceptIDs: selectedConceptIDs,
                        onSelect: onSelect,
                        onCompare: onCompare
                    )
                }
            }
            .padding(22)
        }
        .accessibilityLabel("지식 책장")
    }

    private var visibleCollections: [
        KnowledgeSystemSnapshot.CollectionItem
    ] {
        let visibleCollectionIDs = Set(concepts.map(\.collectionID))
        return snapshot.collections.filter {
            visibleCollectionIDs.contains($0.id)
        }
    }
}

private struct KnowledgeBookshelfSection: View {
    let collection: KnowledgeSystemSnapshot.CollectionItem
    let concepts: [KnowledgeSystemSnapshot.ConceptItem]
    let tint: Color
    let selectedConceptIDs: [KnowledgeConceptID]
    let onSelect: (KnowledgeConceptID) -> Void
    let onCompare: (KnowledgeConceptID) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 210, maximum: 310), spacing: 14),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader

            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(concepts) { item in
                    KnowledgeShelfCard(
                        item: item,
                        tint: tint,
                        isSelected: selectedConceptIDs.contains(item.id),
                        canCompare: !selectedConceptIDs.isEmpty
                            && !selectedConceptIDs.contains(item.id),
                        onSelect: { onSelect(item.id) },
                        onCompare: { onCompare(item.id) }
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var sectionHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: collection.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(collection.title)
                        .font(.title3.weight(.semibold))
                        .accessibilityHeading(.h2)

                    Text("\(concepts.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(tint.opacity(0.10), in: Capsule())
                }

                Text(collection.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct KnowledgeShelfCard: View {
    let item: KnowledgeSystemSnapshot.ConceptItem
    let tint: Color
    let isSelected: Bool
    let canCompare: Bool
    let onSelect: () -> Void
    let onCompare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.concept.title)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if item.latestRevision != nil {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(.purple)
                                .accessibilityLabel("나의 표현 있음")
                        }
                    }

                    Text(item.concept.definition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(conceptAccessibilityLabel)
            .accessibilityHint("개념 상세를 엽니다.")

            Divider()
                .padding(.vertical, 9)

            HStack(spacing: 8) {
                Label(
                    isSelected ? "열어 보는 중" : "간편하게 보기",
                    systemImage: isSelected ? "eye.fill" : "eye"
                )
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? tint : .secondary)

                Spacer(minLength: 4)

                Button(action: onCompare) {
                    Label(
                        "나란히 보기",
                        systemImage: "rectangle.split.2x1"
                    )
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .disabled(!canCompare)
                .help(
                    canCompare
                        ? "현재 개념과 나란히 봅니다."
                        : "먼저 비교할 개념을 하나 열어 주세요."
                )
                .accessibilityLabel("\(item.concept.title) 나란히 보기")
            }
        }
        .padding(14)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(
                    isSelected ? tint.opacity(0.72) : tint.opacity(0.18),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: 5, y: 2)
    }

    private var conceptAccessibilityLabel: String {
        var parts = [item.concept.title, item.concept.definition]
        if item.latestRevision != nil {
            parts.append("나의 표현 있음")
        }
        if isSelected {
            parts.append("현재 선택됨")
        }
        return parts.joined(separator: ". ")
    }
}
