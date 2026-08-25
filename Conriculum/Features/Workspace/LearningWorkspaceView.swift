import ComposableArchitecture
import SwiftUI

struct LearningWorkspaceView: View {
    let store: StoreOf<LearningWorkspaceFeature>

    var body: some View {
        NavigationSplitView(columnVisibility: columnVisibility) {
            KnowledgeContextView(
                store: store.scope(
                    state: \.knowledgeContext,
                    action: \.knowledgeContext
                )
            )
        } detail: {
            ChapterLearningView(
                store: store.scope(
                    state: \.chapter,
                    action: \.chapter
                )
            )
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: inspectorIsPresented) {
            if let inspectorStore = store.scope(
                state: \.knowledgeContext.inspector,
                action: \.knowledgeContext.inspector
            ) {
                ConceptInspectorView(store: inspectorStore)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    store.send(.homeButtonTapped)
                } label: {
                    Label("학습 Home", systemImage: "house")
                }
                .help("학습 Home으로 돌아가기")
                .accessibilityHint("현재 학습 위치를 저장한 채 Home으로 돌아갑니다.")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.focusModeButtonTapped)
                } label: {
                    Label(
                        store.sidebarMode == .focus
                            ? "지식 문맥 보기"
                            : "집중 모드",
                        systemImage: store.sidebarMode == .focus
                            ? "sidebar.left"
                            : "rectangle"
                    )
                }
                .help(
                    store.sidebarMode == .focus
                        ? "집중 모드를 끝내고 지식 문맥을 표시합니다."
                        : "지식 문맥을 숨기고 학습 내용에 집중합니다."
                )
                .accessibilityValue(
                    store.sidebarMode == .focus ? "켜짐" : "꺼짐"
                )
            }
        }
        .frame(minWidth: 720, minHeight: 560)
    }

    private var columnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: {
                store.sidebarMode.navigationSplitViewVisibility
            },
            set: { visibility in
                store.send(.sidebarModeChanged(
                    WorkspaceSidebarMode(visibility: visibility)
                ))
            }
        )
    }

    private var inspectorIsPresented: Binding<Bool> {
        Binding(
            get: { store.knowledgeContext.inspector != nil },
            set: { isPresented in
                guard !isPresented else { return }
                store.send(.knowledgeContext(.inspectorDismissed))
            }
        )
    }
}

extension WorkspaceSidebarMode {
    var navigationSplitViewVisibility: NavigationSplitViewVisibility {
        switch self {
        case .automatic: .automatic
        case .visible: .all
        case .focus: .detailOnly
        }
    }

    init(visibility: NavigationSplitViewVisibility) {
        if visibility == .automatic {
            self = .automatic
        } else if visibility == .all {
            self = .visible
        } else if visibility == .detailOnly {
            self = .focus
        } else {
            self = .automatic
        }
    }
}

#Preview("Workspace · Wide") {
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

#Preview("Workspace · Narrow") {
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

#Preview("Workspace · Focus") {
    LearningWorkspaceView(
        store: Store(
            initialState: LearningWorkspaceFeature.State(
                chapterID: Chapter02.id,
                pageID: "chapter-02-page-03",
                sidebarMode: .focus
            )
        ) {
            LearningWorkspaceFeature()
        }
    )
    .frame(width: 1_100, height: 720)
}
