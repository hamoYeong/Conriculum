import ComposableArchitecture
import SwiftUI

struct KnowledgeSystemView: View {
    let store: StoreOf<KnowledgeSystemFeature>

    var body: some View {
        NavigationSplitView {
            browserSidebar
                .navigationSplitViewColumnWidth(
                    min: 210,
                    ideal: 250,
                    max: 320
                )
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    store.send(.homeButtonTapped)
                } label: {
                    Label("학습 홈", systemImage: "house")
                }
                .help("학습 홈으로 돌아가기")
                .accessibilityHint("현재 탐색 상태를 닫고 학습 홈으로 돌아갑니다.")
            }
        }
        .frame(minWidth: 720, minHeight: 600)
        .task {
            guard store.snapshot == nil else { return }
            await store.send(.task).finish()
        }
    }

    private var browserSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Label("지식 체계", systemImage: "books.vertical")
                    .font(.title2.weight(.semibold))
                    .accessibilityHeading(.h1)

                TextField(
                    "개념, 질문, 예시 검색",
                    text: Binding(
                        get: { store.searchQuery },
                        set: { store.send(.searchQueryChanged($0)) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("지식 검색")
            }
            .padding(16)

            Divider()

            if let snapshot = store.snapshot {
                List {
                    Section("분류") {
                        collectionRow(
                            title: "전체 지식",
                            systemImage: "square.grid.2x2",
                            count: snapshot.concepts.count,
                            collectionID: nil
                        )

                        ForEach(snapshot.collections) { collection in
                            collectionRow(
                                title: collection.title,
                                systemImage: collection.systemImage,
                                count: collection.conceptIDs.count,
                                collectionID: collection.id
                            )
                        }
                    }

                    Section("개념 \(store.visibleConcepts.count)") {
                        if store.visibleConcepts.isEmpty {
                            Text("검색 조건에 맞는 개념이 없습니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(store.visibleConcepts) { item in
                                conceptRow(item)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            } else if store.isLoading {
                ProgressView("분류를 불러오는 중")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("지식 분류를 불러오지 못했습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(16)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func collectionRow(
        title: String,
        systemImage: String,
        count: Int,
        collectionID: KnowledgeCollectionID?
    ) -> some View {
        let isSelected = store.selectedCollectionID == collectionID

        return Button {
            store.send(.collectionSelected(collectionID))
        } label: {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)

                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "선택됨" : "")
    }

    private func conceptRow(
        _ item: KnowledgeSystemSnapshot.ConceptItem
    ) -> some View {
        let isSelected = store.selectedConceptIDs.contains(item.id)

        return Button {
            store.send(.conceptSelected(item.id))
        } label: {
            HStack(spacing: 7) {
                Image(systemName: item.learningStatus.systemImage)
                    .font(.caption)
                    .foregroundStyle(
                        item.learningStatus == .personal ? Color.purple : isSelected ? Color.accentColor : Color.secondary
                    )
                    .accessibilityHidden(true)

                Text(item.concept.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(2)

                if item.latestRevision != nil {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(.purple)
                        .accessibilityLabel("나의 표현 있음")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.isLearned)
        .opacity(item.isLearned ? 1 : 0.55)
        .accessibilityValue(item.learningStatus.title + (isSelected ? ", 상세 열림" : ""))
        .help(item.learningStatus.title)
    }

    @ViewBuilder
    private var detailContent: some View {
        if let snapshot = store.snapshot {
            VStack(spacing: 0) {
                systemHeader(snapshot)

                if let message = store.loadErrorMessage {
                    reloadBanner(message: message)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 10)
                }

                Divider()

                GeometryReader { geometry in
                    workspace(
                        snapshot: snapshot,
                        availableWidth: geometry.size.width
                    )
                }
            }
        } else if let message = store.loadErrorMessage {
            ContentUnavailableView {
                Label(
                    "지식 체계를 불러오지 못했습니다",
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(message)
            } actions: {
                Button("다시 불러오기") {
                    store.send(.retryButtonTapped)
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("지식과 연결을 불러오는 중입니다.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("지식과 연결을 불러오는 중")
        }
    }

    private func systemHeader(
        _ snapshot: KnowledgeSystemSnapshot
    ) -> some View {
        systemTitle(snapshot)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func systemTitle(
        _ snapshot: KnowledgeSystemSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("지식 책장")
                .font(.title.weight(.bold))
                .accessibilityHeading(.h1)
            Text(
                "\(store.contentVersion.title) · \(snapshot.title) · "
                    + "\(store.visibleConcepts.count)개 개념 · "
                    + "\(store.visibleBaseRelations.count)개 기본 연결"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("배운 지식 \(snapshot.concepts.filter { $0.learningStatus == .learned }.count) · 내 지식 \(snapshot.concepts.filter { $0.learningStatus == .personal }.count) · 아직 배우지 않음 \(snapshot.concepts.filter { $0.learningStatus == .unlearned }.count)")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("학습에서 만난 개념은 ‘배운 지식’, 내 설명이나 연결을 남긴 개념은 ‘내 지식’입니다.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func workspace(
        snapshot: KnowledgeSystemSnapshot,
        availableWidth: CGFloat
    ) -> some View {
        let layout = KnowledgeBookshelfLayout.resolve(
            availableWidth: availableWidth,
            hasDetail: !store.selectedConcepts.isEmpty
        )
        // The horizontal allocation is responsive, not a remembered draggable split ratio.
        // Keep the bookshelf in the same structural position to preserve its scroll view.
        HStack(spacing: 0) {
            VSplitView {
                explorer(snapshot: snapshot)
                    .frame(minHeight: 180, maxHeight: .infinity)
                if !store.selectedConcepts.isEmpty && !layout.showsSideDetail {
                    detailArea(snapshot)
                        .frame(minHeight: 180, idealHeight: 300, maxHeight: .infinity)
                }
            }
            .frame(width: layout.shelfWidth)
            if layout.showsSideDetail {
                Divider().frame(width: KnowledgeBookshelfLayout.dividerWidth)
                detailArea(snapshot)
                    .frame(minWidth: KnowledgeBookshelfLayout.minimumDetailWidth, maxWidth: .infinity)
            }
        }
    }

    private func detailArea(_ snapshot: KnowledgeSystemSnapshot) -> some View {
        Group {
            if store.selectedConcepts.count == 1,
               let item = store.selectedConcepts.first {
                detailPane(item, snapshot: snapshot)
            } else {
                VSplitView {
                    ForEach(store.selectedConcepts) { item in
                        detailPane(item, snapshot: snapshot)
                            .frame(minHeight: 160, maxHeight: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func explorer(
        snapshot: KnowledgeSystemSnapshot
    ) -> some View {
        if store.visibleConcepts.isEmpty {
            ContentUnavailableView {
                Label("표시할 지식이 없습니다", systemImage: "magnifyingglass")
            } description: {
                Text("검색어나 분류를 바꾸어 보세요.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            KnowledgeBookshelfView(
                    snapshot: snapshot,
                    concepts: store.visibleConcepts,
                    selectedConceptIDs: store.selectedConceptIDs,
                    onSelect: { store.send(.conceptSelected($0)) },
                    onCompare: {
                        store.send(.compareConceptRequested($0))
                    }
                )
        }
    }

    private func detailPane(
        _ item: KnowledgeSystemSnapshot.ConceptItem,
        snapshot: KnowledgeSystemSnapshot
    ) -> some View {
        KnowledgeSystemDetailPane(
            item: item,
            collection: snapshot.collection(id: item.collectionID),
            baseRelations: snapshot.baseRelations(for: item.id),
            personalRelations: snapshot.personalRelations(for: item.id),
            conceptIndex: KnowledgeConceptIndex(
                concepts: snapshot.concepts.map(\.concept)
            ),
            onClose: {
                store.send(.conceptClosed(item.id))
            },
            onRevisit: {
                store.send(.learningPageTapped($0))
            }
        )
    }

    private func reloadBanner(message: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            KnowledgeMessageBanner(
                title: "최신 지식을 불러오지 못했습니다",
                message: message,
                systemImage: "exclamationmark.triangle",
                accent: .red
            )

            Button("다시 불러오기") {
                store.send(.retryButtonTapped)
            }
        }
    }
}

private struct KnowledgeSystemDetailPane: View {
    let item: KnowledgeSystemSnapshot.ConceptItem
    let collection: KnowledgeSystemSnapshot.CollectionItem?
    let baseRelations: [KnowledgeRelation]
    let personalRelations: [PersonalKnowledgeRelation]
    let conceptIndex: KnowledgeConceptIndex
    let onClose: () -> Void
    let onRevisit: (KnowledgeLearningReference) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    KnowledgeConceptHeader(concept: item.concept)

                    Spacer(minLength: 8)

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .help("이 상세 닫기")
                    .accessibilityLabel("\(item.concept.title) 상세 닫기")
                }

                if let collection {
                    Label(collection.title, systemImage: collection.systemImage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("지식 분류. \(collection.title)")
                }

                BaseKnowledgeSection(
                    concept: item.concept,
                    detailLevel: .complete
                )

                KnowledgeRevisitSection(
                    references: item.concept.revisitPages ?? [],
                    onSelect: onRevisit
                )

                PersonalKnowledgeSection(revision: item.latestRevision)
                if item.learningStatus == .personal && item.latestRevision == nil {
                    Label("학습 응답에 내 설명을 남겼거나 나의 연결이 있는 지식입니다. 기본 지식은 그대로 유지됩니다.", systemImage: item.learningStatus.systemImage)
                        .font(.caption).foregroundStyle(.purple)
                        .fixedSize(horizontal: false, vertical: true)
                }

                KnowledgeRelationsSection(
                    baseRelations: baseRelations,
                    personalRelations: personalRelations,
                    conceptIndex: conceptIndex,
                    focusConceptID: item.id
                )
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
    }
}

#Preview("지식 체계") {
    let catalog = try! ContentResourceDecoder().decode(
        KnowledgeCatalog.self,
            from: V1BundledContentResource.valuesAndTypes
    )
    let snapshot = KnowledgeSystemSnapshotComposer().compose(
        catalog: catalog,
        revisions: [],
        personalRelations: []
    )

    KnowledgeSystemView(
        store: Store(
            initialState: KnowledgeSystemFeature.State(snapshot: snapshot)
        ) {
            KnowledgeSystemFeature()
        }
    )
    .frame(width: 1_100, height: 760)
}
