import AppKit
import ComposableArchitecture
import SwiftUI

struct V1LearningWorkspaceView: View {
    let store: StoreOf<V1LearningWorkspaceFeature>

    var body: some View {
        GeometryReader { geometry in
            let layout = LearningWorkspacePanelLayout.resolve(
                availableWidth: geometry.size.width,
                inspectorIsVisible: inspectorIsVisible,
                sidebarIsHidden: sidebarIsHidden
            )
            let showsSidebar = !sidebarIsHidden && layout != .learningAndInspector
            workspaceContent(
                showsSidebar: showsSidebar,
                availableWidth: geometry.size.width
            )
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
                            store.isFocusModeEnabled
                                ? "집중 모드 끄기"
                                : "집중 모드 켜기",
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
                    .accessibilityValue(
                        store.isFocusModeEnabled ? "켜짐" : "꺼짐"
                    )
                    .focusable(false)

                    Button {
                        store.send(.inspectorVisibilityButtonTapped)
                    } label: {
                        Label(
                            inspectorIsVisible
                                ? "개념 상세 숨기기"
                                : "개념 상세 보기",
                            systemImage: "sidebar.right"
                        )
                    }
                    .help(
                        store.knowledgeContext.inspector == nil
                            ? "지식 문맥에서 개념을 먼저 선택해 주세요."
                            : inspectorIsVisible
                                ? "오른쪽 개념 상세를 숨깁니다."
                                : "선택한 개념의 상세 내용을 표시합니다."
                    )
                    .disabled(store.knowledgeContext.inspector == nil)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 560)
    }

    private func workspaceContent(showsSidebar: Bool, availableWidth: CGFloat) -> some View {
        // 본문은 항상 같은 위치에 둔다. 창 크기 변경으로 본문 트리를
        // 교체하면 ScrollView의 onAppear가 학습 위치를 초기화할 수 있다.
        HSplitView {
            if showsSidebar {
                V1KnowledgeContextView(
                    store: store.scope(
                        state: \.knowledgeContext,
                        action: \.knowledgeContext
                    )
                )
                .frame(minWidth: 200, idealWidth: 300, maxWidth: 300)
            }

            chapterContent
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

            if inspectorIsVisible {
                inspectorContent
                    .frame(minWidth: 240, idealWidth: 360, maxWidth: 360)
            }
        }
    }

    private var chapterContent: some View {
        V1ChapterLearningView(
            store: store.scope(
                state: \.chapter,
                action: \.chapter
            )
        )
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if let inspectorStore = store.scope(
            state: \.knowledgeContext.inspector,
            action: \.knowledgeContext.inspector
        ) {
            V1ConceptInspectorView(store: inspectorStore)
        }
    }

    private func toggleSidebar(isVisible: Bool, availableWidth: CGFloat) {
        if isVisible {
            store.send(.sidebarModeChanged(.hidden))
        } else {
            if store.isFocusModeEnabled {
                store.send(.sidebarVisibilityButtonTapped)
            } else {
                store.send(.sidebarModeChanged(.visible))
            }
            if availableWidth < LearningWorkspacePanelLayout.threePanelMinimumWidth,
               inspectorIsVisible {
                store.send(.inspectorVisibilityButtonTapped)
            }
        }
    }

    private var sidebarIsHidden: Bool {
        store.isFocusModeEnabled || store.sidebarMode == .hidden
    }

    private var inspectorIsVisible: Bool {
        !store.isFocusModeEnabled
            && store.isInspectorPresented
            && store.knowledgeContext.inspector != nil
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

#Preview("학습 공간 · 넓은 창") {
    V1LearningWorkspaceView(
        store: Store(
            initialState: V1LearningWorkspaceFeature.State(
                chapterID: "chapter-02",
                pageID: "chapter-02-overview"
            )
        ) {
            V1LearningWorkspaceFeature()
        }
    )
    .frame(width: 1_100, height: 720)
}

#Preview("학습 공간 · 좁은 창") {
    V1LearningWorkspaceView(
        store: Store(
            initialState: V1LearningWorkspaceFeature.State(
                chapterID: "chapter-02",
                pageID: "chapter-02-overview"
            )
        ) {
            V1LearningWorkspaceFeature()
        }
    )
    .frame(width: 720, height: 720)
}

#Preview("학습 공간 · 집중 모드") {
    V1LearningWorkspaceView(
        store: Store(
            initialState: V1LearningWorkspaceFeature.State(
                chapterID: "chapter-02",
                pageID: "chapter-02-page-03",
                isFocusModeEnabled: true
            )
        ) {
            V1LearningWorkspaceFeature()
        }
    )
    .frame(width: 1_100, height: 720)
}
