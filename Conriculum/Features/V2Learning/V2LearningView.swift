import ComposableArchitecture
import SwiftUI

struct V2LearningView: View {
    let store: StoreOf<V2LearningFeature>

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            content
        }
        .frame(minWidth: 720, minHeight: 600)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    store.send(.homeButtonTapped)
                } label: {
                    Label("학습 홈", systemImage: "house")
                }
                .help("현재 ver.2 학습 위치를 저장하고 홈으로 돌아갑니다.")

                Button {
                    store.send(.sidebarVisibilityButtonTapped)
                } label: {
                    Label(
                        store.sidebarMode == .hidden
                            ? "학습 문맥 보기"
                            : "학습 문맥 숨기기",
                        systemImage: "sidebar.left"
                    )
                }
                .help("챕터 페이지와 현재 지식 단서를 보여 주는 사이드바를 전환합니다.")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.send(.focusModeButtonTapped)
                } label: {
                    Label(
                        store.isFocusModeEnabled ? "집중 모드 끄기" : "집중 모드 켜기",
                        systemImage: store.isFocusModeEnabled
                            ? "viewfinder.circle.fill"
                            : "viewfinder"
                    )
                }
                .help("집중 모드는 학습 문맥과 지식 단서를 잠시 숨깁니다.")
                .accessibilityValue(store.isFocusModeEnabled ? "켜짐" : "꺼짐")

                Button {
                    store.send(.inspectorVisibilityButtonTapped)
                } label: {
                    Label(
                        store.isInspectorPresented ? "지식 단서 숨기기" : "지식 단서 보기",
                        systemImage: "sidebar.right"
                    )
                }
                .disabled(store.selectedKnowledgeConcept == nil)
                .help("선택한 개념의 정의와 판단 질문을 오른쪽에서 확인합니다.")
            }
        }
        .task {
            guard store.page == nil else { return }
            await store.send(.task).finish()
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading, store.page == nil {
            ProgressView("ver.2 학습 페이지를 불러오는 중…")
        } else if let message = store.loadErrorMessage, store.page == nil {
            ContentUnavailableView {
                Label("ver.2 페이지를 열 수 없습니다", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("다시 시도") { store.send(.task) }
                Button("홈으로") { store.send(.homeButtonTapped) }
            }
        } else if let page = store.page, let stage = store.stage {
            learningWorkspace(page, stage: stage)
        }
    }

    private func learningWorkspace(
        _ page: V2LearningPage,
        stage: V2Stage
    ) -> some View {
        GeometryReader { geometry in
            let inspectorIsVisible = !store.isFocusModeEnabled
                && store.isInspectorPresented
                && store.selectedKnowledgeConcept != nil
            let sidebarIsVisible = !store.isFocusModeEnabled
                && store.sidebarMode != .hidden
                && (!inspectorIsVisible || geometry.size.width >= 920)

            HSplitView {
                if sidebarIsVisible, let chapter = store.chapter {
                    V2LearningSidebar(
                        stage: stage,
                        chapter: chapter,
                        currentPageID: page.id,
                        completedPageIDs: store.progress.completedPageIDs,
                        concepts: store.pageKnowledgeConcepts,
                        selectedConceptID: store.selectedKnowledgeConceptID,
                        onPageSelected: { store.send(.pageSelected($0)) },
                        onConceptSelected: {
                            store.send(.knowledgeConceptSelected($0))
                        }
                    )
                    .frame(minWidth: 210, idealWidth: 280, maxWidth: 300)
                }

                learningPage(page, stage: stage)
                    .frame(minWidth: 400, maxWidth: .infinity)

                if inspectorIsVisible,
                   let concept = store.selectedKnowledgeConcept {
                    V2KnowledgeInspector(
                        concept: concept,
                        onDismiss: { store.send(.inspectorDismissed) }
                    )
                    .frame(minWidth: 250, idealWidth: 330, maxWidth: 360)
                }
            }
        }
    }

    private func learningPage(_ page: V2LearningPage, stage: V2Stage) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("STAGE \(stage.order) · CHAPTER \(store.chapter?.order ?? 0)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let position = store.position {
                                Text("전체 \(position) / \(store.orderedPages.count)")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(page.title)
                            .font(.largeTitle.bold())
                            .accessibilityHeading(.h1)
                        Text(page.goal)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    if stage.kind == .game {
                        V2StageOneGameComponent(page: page)
                    } else {
                        V2StageTwoLearningComponent(page: page)
                    }
                }
                .frame(maxWidth: 820, alignment: .leading)
                .padding(32)
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 0) {
                if let message = store.saveErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }
                Divider()
                HStack {
                    Button("이전", systemImage: "chevron.left") {
                        store.send(.previousButtonTapped)
                    }
                    .disabled(!store.canGoPrevious || store.isSaving)
                    Spacer()
                    if store.progress.completedPageIDs.contains(page.id) {
                        Label("완료", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Button(
                        store.isLastPage ? "학습 완료" : "완료하고 다음",
                        systemImage: store.isLastPage ? "checkmark" : "chevron.right"
                    ) {
                        store.send(.nextButtonTapped)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isSaving)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .background(.bar)
        }
    }
}
