import AppKit
import ComposableArchitecture
import SwiftUI

struct LearningView: View {
    let store: StoreOf<LearningFeature>

    var body: some View {
        GeometryReader { geometry in
            let layout = LearningWorkspacePanelLayout.resolve(
                availableWidth: geometry.size.width,
                inspectorIsVisible: inspectorIsVisible,
                sidebarIsHidden: sidebarIsHidden
            )
            let showsSidebar = !sidebarIsHidden && layout != .learningAndInspector

            ZStack {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
                content(showsSidebar: showsSidebar, availableWidth: geometry.size.width)
            }
            .toolbar(removing: .sidebarToggle)
            .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    store.send(.homeButtonTapped)
                } label: {
                    Label("학습 홈", systemImage: "house")
                }
                .help("학습 홈으로 돌아가기")
                .accessibilityHint("현재 학습 위치를 저장한 채 학습 홈으로 돌아갑니다.")

                Button {
                    toggleSidebar(
                        isVisible: showsSidebar,
                        availableWidth: geometry.size.width
                    )
                } label: {
                    Label(
                        showsSidebar ? "학습 문맥 숨기기" : "학습 문맥 보기",
                        systemImage: "sidebar.left"
                    )
                }
                .help(showsSidebar
                    ? "왼쪽 학습 문맥을 숨깁니다."
                    : "학습 문맥을 표시합니다. 좁은 창에서는 개념 상세와 번갈아 봅니다.")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    toggleFocusModePreservingFirstResponder()
                } label: {
                    Label(
                        store.isFocusModeEnabled ? "집중 모드 끄기" : "집중 모드 켜기",
                        systemImage: store.isFocusModeEnabled
                            ? "viewfinder.circle.fill"
                            : "viewfinder"
                    )
                }
                .help(
                    store.isFocusModeEnabled
                        ? "집중 모드를 끝내고 이전 패널 표시 상태를 복원합니다."
                        : "지식 문맥과 개념 상세를 숨기고 학습 내용에 집중합니다."
                )
                .accessibilityValue(store.isFocusModeEnabled ? "켜짐" : "꺼짐")
                .focusable(false)

                Button {
                    store.send(.inspectorVisibilityButtonTapped)
                } label: {
                    Label(
                        inspectorIsVisible ? "개념 상세 숨기기" : "개념 상세 보기",
                        systemImage: "sidebar.right"
                    )
                }
                .disabled(store.selectedKnowledgeConcept == nil)
                .help(
                    store.selectedKnowledgeConcept == nil
                        ? "지식 문맥에서 개념을 먼저 선택해 주세요."
                        : inspectorIsVisible
                            ? "오른쪽 개념 상세를 숨깁니다."
                            : "선택한 개념의 상세 내용을 표시합니다."
                )
            }
            }
        }
        .frame(minWidth: 680, minHeight: 560)
        .task {
            guard store.page == nil else { return }
            await store.send(.task).finish()
        }
    }

    @ViewBuilder
    private func content(showsSidebar: Bool, availableWidth: CGFloat) -> some View {
        if store.isLoading, store.page == nil {
            ProgressView("학습 페이지를 불러오는 중…")
        } else if let message = store.loadErrorMessage, store.page == nil {
            ContentUnavailableView {
                Label("페이지를 열 수 없습니다", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("다시 시도") { store.send(.task) }
                Button("홈으로") { store.send(.homeButtonTapped) }
            }
        } else if let page = store.page, let stage = store.stage {
            learningWorkspace(
                page,
                stage: stage,
                showsSidebar: showsSidebar,
                availableWidth: availableWidth
            )
        }
    }

    private func learningWorkspace(
        _ page: LessonPage,
        stage: LearningStage,
        showsSidebar: Bool,
        availableWidth: CGFloat
    ) -> some View {
        HSplitView {
                if showsSidebar, let chapter = store.chapter {
                    LearningSidebar(
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
                    .frame(minWidth: 380, maxWidth: .infinity)
                    .background {
                        LearningWorkspacePanelSizing(
                            configuration: .init(
                                showsSidebar: showsSidebar,
                                showsInspector: inspectorIsVisible,
                                availableWidth: availableWidth
                            )
                        )
                    }

                if inspectorIsVisible,
                   let concept = store.selectedKnowledgeConcept {
                    KnowledgeInspector(
                        concept: concept,
                        relations: store.knowledgeCatalog?.relations ?? [],
                        concepts: store.knowledgeCatalog?.concepts ?? [],
                        onDismiss: { store.send(.inspectorDismissed) }
                    )
                    .frame(minWidth: 250, idealWidth: 330, maxWidth: 360)
                }
        }
    }

    private func learningPage(_ page: LessonPage, stage: LearningStage) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Chapter \(store.chapter?.order ?? 0) · \(page.order) / \(store.chapter?.pages.count ?? 0)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                        Text(page.title)
                            .font(.largeTitle.bold())
                            .accessibilityHeading(.h1)
                        Text(page.goal)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    if stage.kind == .game {
                        StageOneGameComponent(
                            page: page,
                            responses: store.progress.activityResponses,
                            drafts: store.gameDrafts,
                            onOptionTapped: { activityID, optionID in
                                store.send(.gameOptionTapped(
                                    activityID: activityID,
                                    optionID: optionID
                                ))
                            },
                            onMatchChanged: { activityID, pairID, rightPairID in
                                store.send(.gameMatchChanged(
                                    activityID: activityID,
                                    pairID: pairID,
                                    rightPairID: rightPairID
                                ))
                            },
                            onSubmit: { store.send(.gameSubmitTapped(activityID: $0)) }
                        )
                    } else {
                        StageTwoLearningComponent(page: page)
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
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
                    if let position = store.position {
                        Text("\(position) / \(store.orderedPages.count)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("학습 페이지 \(store.orderedPages.count)개 중 \(position)번째")
                    }
                    Spacer()
                    Button(
                        store.isLastPage ? "완료 요약" : "다음",
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

    private var sidebarIsHidden: Bool {
        store.isFocusModeEnabled || store.sidebarMode == .hidden
    }

    private var inspectorIsVisible: Bool {
        !store.isFocusModeEnabled
            && store.isInspectorPresented
            && store.selectedKnowledgeConcept != nil
    }

    private func toggleSidebar(isVisible: Bool, availableWidth: CGFloat) {
        if isVisible {
            store.send(.sidebarModeChanged(.hidden))
        } else {
            store.send(.sidebarModeChanged(.visible))
            if availableWidth < LearningWorkspacePanelLayout.threePanelMinimumWidth,
               inspectorIsVisible {
                store.send(.inspectorVisibilityButtonTapped)
            }
        }
    }

    private func toggleFocusModePreservingFirstResponder() {
        let window = NSApp.keyWindow
        let firstResponder = window?.firstResponder
        store.send(.focusModeButtonTapped)

        guard let window, let firstResponder else { return }
        Task { @MainActor in
            await Task.yield()
            window.makeFirstResponder(firstResponder)
        }
    }
}
