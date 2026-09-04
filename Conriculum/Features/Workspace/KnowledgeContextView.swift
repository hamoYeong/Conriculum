import ComposableArchitecture
import SwiftUI

struct KnowledgeContextView: View {
    let store: StoreOf<KnowledgeContextFeature>

    @State private var isChangesExpanded = false
    @State private var isNearbyExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let message = store.loadErrorMessage {
                    errorBanner(message)
                }

                if let snapshot = store.snapshot {
                    snapshotContent(snapshot)
                } else if store.isLoading {
                    ProgressView("학습 문맥을 불러오는 중…")
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 220)
                        .accessibilityLabel("현재 학습 문맥 불러오는 중")
                } else {
                    unavailableContent
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityLabel("현재 학습의 지식 문맥")
        .task {
            guard store.snapshot == nil else { return }
            await store.send(.task).finish()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Label("학습 문맥", systemImage: "scope")
                .font(.headline)
                .accessibilityHeading(.h1)

            Spacer()

            if store.isLoading, store.snapshot != nil {
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityLabel("학습 문맥 갱신 중")
            }
        }
    }

    private func snapshotContent(
        _ snapshot: KnowledgeContextSnapshot
    ) -> some View {
        let changeCollection = KnowledgeChangeCollectionComposer().compose(
            concepts: snapshot.availableConcepts,
            revisions: snapshot.changedConcepts.compactMap(
                \.personalRevision
            ),
            relations: snapshot.personalRelations,
            pendingReviews: store.pendingPersonalizationReviews
        )

        return VStack(alignment: .leading, spacing: 18) {
            questionCard(snapshot.currentQuestion)

            if let core = snapshot.directConcepts.first {
                coreCriterionCard(core)
            }

            let supporting = Array(snapshot.directConcepts.dropFirst().prefix(2))
            if supporting.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel(
                        title: "함께 쓰는 개념",
                        systemImage: "link",
                        accent: .teal
                    )

                    ForEach(supporting) { item in
                        compactConceptRow(item, accent: .teal)
                    }
                }
            }

            collapsibleHeader(
                title: "내가 바꾼 설명",
                systemImage: "sparkles",
                count: snapshot.changedConcepts.count
                    + snapshot.personalRelations.count
                    + store.pendingPersonalizationReviews.count,
                summary: snapshot.changedKnowledgeSummary,
                isExpanded: isChangesExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isChangesExpanded.toggle()
                }
            }

            if isChangesExpanded {
                KnowledgeChangeCollectionView(
                    collection: changeCollection,
                    confirmedEmptyMessage: snapshot.emptyStateMessage,
                    onConceptSelected: { conceptID in
                        store.send(.conceptSelected(conceptID))
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            collapsibleHeader(
                title: "왜 이어지는가",
                systemImage: "arrow.triangle.branch",
                count: snapshot.nearbyConcepts.count,
                summary: "핵심 활동 뒤 필요할 때 가까운 지식과 연결 이유를 봅니다.",
                isExpanded: isNearbyExpanded
            ) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isNearbyExpanded.toggle()
                }
            }

            if isNearbyExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(snapshot.nearbyConcepts) { item in
                        nearbyConceptRow(item)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func questionCard(_ question: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("지금의 질문", systemImage: "questionmark.bubble.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)

            Text(question)
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.blue.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func coreCriterionCard(
        _ item: KnowledgeContextSnapshot.ConceptItem
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(
                title: "지금 쓰는 기준",
                systemImage: "target",
                accent: .blue
            )

            Button {
                store.send(.conceptSelected(item.id))
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.concept.title)
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Text("핵심")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.10), in: Capsule())
                    }

                    Text(item.concept.definition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let usage = item.usage {
                        Text("이 활동에서는 · \(usage)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.blue)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.blue.opacity(0.18), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(conceptAccessibilityLabel(item))
            .accessibilityHint("개념의 기본 지식과 나의 표현을 비교합니다.")
        }
    }

    private func compactConceptRow(
        _ item: KnowledgeContextSnapshot.ConceptItem,
        accent: Color
    ) -> some View {
        Button {
            store.send(.conceptSelected(item.id))
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(accent)
                    .padding(.top, 6)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.concept.title)
                        .font(.callout.weight(.semibold))
                    if let usage = item.usage {
                        Text(usage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(conceptAccessibilityLabel(item))
        .accessibilityHint("개념 상세를 엽니다.")
    }

    private func nearbyConceptRow(
        _ item: KnowledgeContextSnapshot.ConceptItem
    ) -> some View {
        Button {
            store.send(.conceptSelected(item.id))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.concept.title)
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }

                if let reason = item.nearbyReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.75),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(conceptAccessibilityLabel(item))
    }

    private func collapsibleHeader(
        title: String,
        systemImage: String,
        count: Int,
        summary: String,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.purple)
                    .frame(width: 18)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(title)
                            .font(.callout.weight(.semibold))
                        Text("\(count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
            }
            .padding(11)
            .contentShape(Rectangle())
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.65),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count)개")
        .accessibilityValue(isExpanded ? "펼쳐짐" : "접힘")
        .accessibilityHint(isExpanded ? "접기" : "펼치기")
    }

    private func sectionLabel(
        title: String,
        systemImage: String,
        accent: Color
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent)
            .accessibilityHeading(.h2)
    }

    private func conceptAccessibilityLabel(
        _ item: KnowledgeContextSnapshot.ConceptItem
    ) -> String {
        var parts = [item.concept.title]
        if let usage = item.usage {
            parts.append("현재 활동에서 \(usage)")
        }
        if let reason = item.nearbyReason {
            parts.append("이어지는 이유 \(reason)")
        }
        if item.personalRevision != nil {
            parts.append("확인해 저장한 나의 표현 있음")
        }
        return parts.joined(separator: ". ")
    }

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                "지식 문맥을 갱신하지 못했습니다",
                systemImage: "exclamationmark.triangle"
            )
            .font(.callout.weight(.semibold))
            Text(message)
                .font(.caption)
            Button("다시 불러오기") {
                store.send(.reloadRequested(.initial))
            }
            .controlSize(.small)
        }
        .foregroundStyle(.red)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.red.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    private var unavailableContent: some View {
        ContentUnavailableView {
            Label("연결된 지식이 없습니다", systemImage: "books.vertical")
        } description: {
            Text("현재 페이지의 지식 문맥을 다시 불러와 주세요.")
        } actions: {
            Button("불러오기") {
                store.send(.reloadRequested(.initial))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
    }
}

#Preview("지식 문맥 · 비어 있음") {
    KnowledgeContextView(
        store: Store(
            initialState: KnowledgeContextPreviewData.emptyState
        ) {
            KnowledgeContextFeature()
        }
    )
    .frame(width: 320, height: 720)
}

#Preview("지식 문맥 · 개인화") {
    KnowledgeContextView(
        store: Store(
            initialState: KnowledgeContextPreviewData.personalizedState
        ) {
            KnowledgeContextFeature()
        }
    )
    .frame(width: 320, height: 720)
}

private enum KnowledgeContextPreviewData {
    private static let value = KnowledgeConcept(
        id: "concept-value",
        title: "값",
        definition: "프로그램이 저장하고 읽고 사용할 수 있도록 하나로 정해진 정보다.",
        essentialQuestion: "무엇이 하나로 정해진 정보인가?",
        judgmentQuestions: [],
        examples: [],
        misconceptions: []
    )
    private static let type = KnowledgeConcept(
        id: "concept-type",
        title: "타입",
        definition: "값의 종류와 허용되는 사용을 정하는 약속이다.",
        essentialQuestion: "이 값으로 무엇을 할 것인가?",
        judgmentQuestions: [],
        examples: [],
        misconceptions: []
    )
    private static let revision = PersonalConceptRevision(
        id: "revision-preview-value",
        conceptID: value.id,
        personalTitle: "하나로 정해진 정보",
        explanation: "값은 이번 사례에서 프로그램이 직접 다룰 수 있게 하나로 정한 정보다.",
        examples: [],
        previousRevisionID: nil,
        evidenceActivityID: "activity-page01-choice",
        createdAt: Date(timeIntervalSince1970: 1_725_782_400)
    )

    static let emptyState = state(revision: nil)
    static let personalizedState = state(revision: revision)

    private static func state(
        revision: PersonalConceptRevision?
    ) -> KnowledgeContextFeature.State {
        let direct = KnowledgeContextSnapshot.ConceptItem(
            concept: value,
            personalRevision: revision,
            revisionEvidenceActivityID: "activity-page01-choice",
            role: .primary,
            usage: "현실 정보에서 구체적인 값을 찾는다.",
            nearbyReason: nil
        )
        let nearby = KnowledgeContextSnapshot.ConceptItem(
            concept: type,
            personalRevision: nil,
            revisionEvidenceActivityID: nil,
            role: nil,
            usage: nil,
            nearbyReason: "찾은 값을 어떤 종류로 다룰지는 다음 페이지에서 판단한다."
        )
        let snapshot = KnowledgeContextSnapshot(
            pageID: "chapter-02-page-01",
            pageTitle: "현실의 정보를 값으로 바라보기",
            currentQuestion: "현실의 설명에서 무엇이 현재 사례의 구체적인 값인가?",
            currentlyUsedSummary: "현재 활동에 직접 쓰는 값 개념을 보여 준다.",
            changedKnowledgeSummary: "확인해 저장한 나의 표현을 보여 준다.",
            emptyStateMessage: "아직 확인해 반영한 값·규칙 구분 기준이 없다.",
            focusModeSummary: "현재 개념명과 저장된 변화 유무만 유지한다.",
            directConcepts: [direct],
            changedConcepts: revision == nil ? [] : [direct],
            nearbyConcepts: [nearby],
            availableConcepts: [value, type],
            baseRelations: [],
            personalRelations: [],
            relationCreationContract: nil
        )
        return KnowledgeContextFeature.State(
            chapterID: "chapter-02",
            currentPageID: snapshot.pageID,
            snapshot: snapshot
        )
    }
}
