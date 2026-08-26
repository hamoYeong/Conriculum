import ComposableArchitecture
import SwiftUI

struct KnowledgeContextView: View {
    let store: StoreOf<KnowledgeContextFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let message = store.loadErrorMessage {
                    errorBanner(message)
                }

                if let snapshot = store.snapshot {
                    snapshotContent(snapshot)
                } else if store.isLoading {
                    ProgressView("현재 페이지의 지식을 불러오는 중…")
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 260)
                        .accessibilityLabel("현재 페이지의 지식 문맥 불러오는 중")
                } else {
                    unavailableContent
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        .accessibilityLabel("현재 학습의 지식 문맥")
        .task {
            guard store.snapshot == nil else { return }
            await store.send(.task).finish()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(
                    "지식 문맥",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
                .font(.title2.weight(.semibold))
                .accessibilityHeading(.h1)

                Spacer()

                if store.isLoading, store.snapshot != nil {
                    ProgressView()
                        .controlSize(.mini)
                        .accessibilityLabel("지식 문맥 갱신 중")
                }
            }

            Text("현재 학습에 쓰는 개념과 확인해 반영한 나의 지식을 함께 봅니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func snapshotContent(
        _ snapshot: KnowledgeContextSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Divider()

            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot.pageTitle)
                    .font(.headline)
                Text(snapshot.currentlyUsedSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "현재 페이지 \(snapshot.pageTitle). "
                    + snapshot.currentlyUsedSummary
            )

            contextSection(
                title: "지금 쓰는 지식",
                systemImage: "scope",
                accent: .blue,
                items: snapshot.directConcepts
            )

            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(
                    title: "이번 학습으로 달라진 지식",
                    systemImage: "sparkles",
                    accent: .purple
                )

                Text(snapshot.changedKnowledgeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                KnowledgeChangeCollectionView(
                    collection: KnowledgeChangeCollectionComposer().compose(
                        concepts: snapshot.availableConcepts,
                        revisions: snapshot.changedConcepts.compactMap(
                            \.personalRevision
                        ),
                        relations: snapshot.personalRelations,
                        pendingReviews: store
                            .pendingPersonalizationReviews
                    ),
                    confirmedEmptyMessage: snapshot.emptyStateMessage,
                    onConceptSelected: { conceptID in
                        store.send(.conceptSelected(conceptID))
                    }
                )
            }

            contextSection(
                title: "가까운 지식",
                systemImage: "circle.grid.cross",
                accent: .teal,
                items: snapshot.nearbyConcepts
            )

            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text("집중 모드 요약")
                        .font(.caption.weight(.semibold))
                    Text(snapshot.focusModeSummary)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "rectangle.inset.filled")
            }
            .foregroundStyle(.secondary)
            .padding(12)
            .background(
                Color(nsColor: .controlBackgroundColor).opacity(0.7),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .accessibilityElement(children: .combine)
        }
    }

    private func contextSection(
        title: String,
        systemImage: String,
        accent: Color,
        items: [KnowledgeContextSnapshot.ConceptItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: title,
                systemImage: systemImage,
                accent: accent
            )

            ForEach(items) { item in
                conceptCard(item, accent: accent)
            }
        }
    }

    private func sectionHeader(
        title: String,
        systemImage: String,
        accent: Color
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(accent)
            .accessibilityHeading(.h2)
    }

    private func conceptCard(
        _ item: KnowledgeContextSnapshot.ConceptItem,
        accent: Color
    ) -> some View {
        Button {
            store.send(.conceptSelected(item.id))
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.concept.title)
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let role = item.role {
                        Text(roleTitle(role))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.10), in: Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }

                Text(item.concept.definition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let usage = item.usage {
                    Label(usage, systemImage: "arrow.turn.down.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let reason = item.nearbyReason {
                    Label(reason, systemImage: "link")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                if let revision = item.personalRevision {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            revision.personalTitle?.isEmpty == false
                                ? revision.personalTitle ?? "나의 표현"
                                : "나의 표현",
                            systemImage: "person.crop.circle.fill"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)

                        Text(revision.explanation)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Label("나의 표현 없음", systemImage: "person.crop.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .contentShape(Rectangle())
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(conceptAccessibilityLabel(item))
        .accessibilityHint("기본 지식과 나의 표현을 개념 상세에서 비교합니다.")
    }

    private func conceptAccessibilityLabel(
        _ item: KnowledgeContextSnapshot.ConceptItem
    ) -> String {
        var parts = [item.concept.title, item.concept.definition]
        if let role = item.role {
            parts.append("현재 페이지 역할 \(roleTitle(role))")
        }
        if let revision = item.personalRevision {
            parts.append("나의 표현 \(revision.explanation)")
        } else {
            parts.append("나의 표현 없음")
        }
        if let reason = item.nearbyReason {
            parts.append("가까운 지식으로 표시한 이유 \(reason)")
        }
        return parts.joined(separator: ". ")
    }

    private func roleTitle(_ role: KnowledgeLinkRole) -> String {
        switch role {
        case .primary: "핵심"
        case .supporting: "보조"
        case .prerequisite: "선행"
        case .enrichment: "확장·심화"
        }
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
            chapterID: Chapter02.id,
            currentPageID: snapshot.pageID,
            snapshot: snapshot
        )
    }
}
