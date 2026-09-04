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
    @State private var visibleConceptID: KnowledgeConceptID?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    if !selectedConceptIDs.isEmpty {
                        Text("선택한 지식과 직접 연결된 카드에 관계 유형을 표시합니다. 관계의 방향과 설명은 상세에서 확인하세요.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
                            tint: KnowledgeCollectionTint.color(for: collectionIndex),
                            selectedConceptIDs: selectedConceptIDs,
                            relatedKinds: { item in
                                snapshot.relationKinds(from: selectedConceptIDs, to: item.id)
                            },
                            hasPersonalRelation: { item in
                                snapshot.hasPersonalRelation(from: selectedConceptIDs, to: item.id)
                            },
                            onSelect: onSelect,
                            onCompare: onCompare
                        )
                    }
                }
                .frame(width: max(KnowledgeBookshelfLayout.cardWidth, geometry.size.width - 2 * KnowledgeBookshelfLayout.shelfPadding), alignment: .leading)
                .padding(KnowledgeBookshelfLayout.shelfPadding)
            }
            .scrollPosition(id: $visibleConceptID, anchor: .top)
            .accessibilityLabel("지식 책장")
        }
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
    let relatedKinds: (KnowledgeSystemSnapshot.ConceptItem) -> Set<KnowledgeRelationKind>
    let hasPersonalRelation: (KnowledgeSystemSnapshot.ConceptItem) -> Bool
    let onSelect: (KnowledgeConceptID) -> Void
    let onCompare: (KnowledgeConceptID) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: KnowledgeBookshelfLayout.cardWidth, maximum: KnowledgeBookshelfLayout.cardWidth), spacing: KnowledgeBookshelfLayout.columnSpacing),
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
                        relationKinds: relatedKinds(item),
                        hasPersonalRelation: hasPersonalRelation(item),
                        canCompare: item.isLearned && !selectedConceptIDs.isEmpty
                            && !selectedConceptIDs.contains(item.id),
                        onSelect: { onSelect(item.id) },
                        onCompare: { onCompare(item.id) }
                    )
                }
            }
            .scrollTargetLayout()
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
    let relationKinds: Set<KnowledgeRelationKind>
    let hasPersonalRelation: Bool
    let canCompare: Bool
    let onSelect: () -> Void
    let onCompare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
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
                .disabled(!item.isLearned)
                .accessibilityLabel(conceptAccessibilityLabel)
                .accessibilityHint(item.isLearned ? "개념 상세를 엽니다." : "이 지식을 다루는 학습 페이지를 지나오면 상세를 열 수 있습니다.")

                compareButton
            }

            Divider()
                .padding(.vertical, 9)

            KnowledgeShelfMetadataRow(
                status: item.learningStatus,
                tint: tint,
                relationKinds: relationKinds,
                hasPersonalRelation: hasPersonalRelation
            )
        }
        .padding(14)
        .background(
            relationColor?.opacity(0.10) ?? (item.isLearned ? Color(nsColor: .controlBackgroundColor) : Color.primary.opacity(0.035)),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(
                    isSelected ? tint.opacity(0.72) : relationColor?.opacity(0.75) ?? tint.opacity(item.isLearned ? 0.18 : 0.08),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: 5, y: 2)
        .opacity(item.isLearned ? 1 : 0.58)
        .frame(width: KnowledgeBookshelfLayout.cardWidth)
    }

    private var compareButton: some View {
        Button(action: onCompare) {
            Label("나란히 보기", systemImage: "rectangle.split.2x1")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderless)
        .disabled(!canCompare)
        .help(canCompare ? "현재 개념과 나란히 봅니다." : "먼저 비교할 개념을 하나 열어 주세요.")
        .accessibilityLabel("\(item.concept.title) 나란히 보기")
    }

    private var conceptAccessibilityLabel: String {
        var parts = [item.concept.title, item.learningStatus.title, item.concept.definition]
        if item.latestRevision != nil {
            parts.append("나의 표현 있음")
        }
        if isSelected {
            parts.append("현재 선택됨")
        }
        return parts.joined(separator: ". ")
    }

    private var relationColor: Color? {
        guard let kind = KnowledgeRelationKind.allCases.first(where: relationKinds.contains) else {
            return hasPersonalRelation ? .purple : nil
        }
        return KnowledgeRelationTint.color(for: kind)
    }
}

/// Keep status and relationship on one line. Extra relations remain available in a popover.
struct KnowledgeShelfMetadataRow: View {
    let status: KnowledgeSystemSnapshot.LearningStatus
    let tint: Color
    let relationKinds: Set<KnowledgeRelationKind>
    let hasPersonalRelation: Bool
    @State private var showsAllRelations = false

    private var badges: [Badge] {
        KnowledgeRelationKind.allCases.filter(relationKinds.contains).map { kind in
            Badge(title: compactTitle(kind), fullTitle: KnowledgePresentation.title(for: kind), color: KnowledgeRelationTint.color(for: kind))
        } + (hasPersonalRelation ? [Badge(title: "나의 연결", fullTitle: "나의 연결", color: .purple)] : [])
    }

    var body: some View {
        HStack(spacing: 5) {
            Label(status.title, systemImage: status.systemImage)
                .font(.caption2.weight(.medium))
                .foregroundStyle(status == .personal ? Color.purple : status == .learned ? tint : .secondary)
                .fixedSize()

            Spacer(minLength: 0)

            if let badge = badges.first {
                chip(badge)
            }
            if badges.count > 1 {
                Button("+\(badges.count - 1)") { showsAllRelations = true }
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.plain)
                    .fixedSize()
                    .help(badges.map(\.fullTitle).joined(separator: ", "))
                    .accessibilityLabel("관계 유형 \(badges.count)개 모두 보기")
                    .popover(isPresented: $showsAllRelations) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("선택한 지식과의 관계").font(.headline)
                            ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                                Label(badge.fullTitle, systemImage: "link")
                                    .foregroundStyle(badge.color)
                            }
                        }
                        .padding(16)
                    }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func chip(_ badge: Badge) -> some View {
        Text(badge.title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(badge.color)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(badge.color.opacity(0.12), in: Capsule())
            .fixedSize()
            .help(badge.fullTitle)
            .accessibilityLabel(badge.fullTitle)
    }

    private func compactTitle(_ kind: KnowledgeRelationKind) -> String {
        switch kind {
        case .prerequisite: "선행"
        case .related: "관련"
        case .contrastsWith: "대조"
        case .refines: "구체화"
        case .appliesTo: "적용"
        case .leadsTo: "다음 연결"
        }
    }

    private struct Badge {
        let title: String
        let fullTitle: String
        let color: Color
    }
}

enum KnowledgeRelationTint {
    static func color(for kind: KnowledgeRelationKind) -> Color {
        switch kind {
        case .prerequisite: .orange
        case .related: .teal
        case .contrastsWith: .pink
        case .refines: .indigo
        case .appliesTo: .green
        case .leadsTo: .blue
        }
    }
}
