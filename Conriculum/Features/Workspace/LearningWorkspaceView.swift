import AppKit
import ComposableArchitecture
import SwiftUI

struct LearningWorkspaceView: View {
    let store: StoreOf<LearningWorkspaceFeature>

    var body: some View {
        workspaceContent
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
            .frame(minWidth: 680, minHeight: 560)
    }

    @ViewBuilder
    private var workspaceContent: some View {
        if inspectorIsVisible,
           let inspectorStore = store.scope(
               state: \.knowledgeContext.inspector,
               action: \.knowledgeContext.inspector
           )
        {
            HSplitView {
                navigationContent
                    .frame(minWidth: 420, maxWidth: .infinity)

                ConceptInspectorView(store: inspectorStore)
                    .frame(minWidth: 220, idealWidth: 240, maxWidth: 360)
            }
        } else {
            navigationContent
        }
    }

    private var navigationContent: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
            KnowledgeContextView(
                store: store.scope(
                    state: \.knowledgeContext,
                    action: \.knowledgeContext
                )
            )
            .accessibilityHidden(
                store.isFocusModeEnabled
                    || store.sidebarMode.hidesKnowledgeContextFromAccessibility
            )
        } detail: {
            ChapterLearningView(
                store: store.scope(
                    state: \.chapter,
                    action: \.chapter
                )
            )
        }
        .navigationSplitViewStyle(.prominentDetail)
    }

    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: {
                store.isFocusModeEnabled
                    ? .detailOnly
                    : store.sidebarMode.navigationSplitViewVisibility
            },
            set: { visibility in
                store.send(.sidebarModeChanged(
                    WorkspaceSidebarMode(visibility: visibility)
                ))
            }
        )
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

extension WorkspaceSidebarMode {
    var hidesKnowledgeContextFromAccessibility: Bool {
        self == .hidden
    }

    var navigationSplitViewVisibility: NavigationSplitViewVisibility {
        switch self {
        case .automatic: .automatic
        case .visible: .all
        case .hidden: .detailOnly
        }
    }

    init(visibility: NavigationSplitViewVisibility) {
        if visibility == .automatic {
            self = .automatic
        } else if visibility == .all {
            self = .visible
        } else if visibility == .detailOnly {
            self = .hidden
        } else {
            self = .automatic
        }
    }
}

#Preview("학습 공간 · 넓은 창") {
    LearningWorkspaceView(
        store: Store(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: "chapter-02-overview"
            )
        ) {
            LearningWorkspaceFeature()
        }
    )
    .frame(width: 1_100, height: 720)
}

#Preview("학습 공간 · 좁은 창") {
    LearningWorkspaceView(
        store: Store(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: "chapter-02-overview"
            )
        ) {
            LearningWorkspaceFeature()
        }
    )
    .frame(width: 720, height: 720)
}

#Preview("학습 공간 · 집중 모드") {
    LearningWorkspaceView(
        store: Store(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: "chapter-02-page-03",
                isFocusModeEnabled: true
            )
        ) {
            LearningWorkspaceFeature()
        }
    )
    .frame(width: 1_100, height: 720)
}
