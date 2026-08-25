import ComposableArchitecture
import SwiftUI

struct LearningWorkspaceView: View {
    let store: StoreOf<LearningWorkspaceFeature>

    var body: some View {
        NavigationSplitView {
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
        }
        .frame(minWidth: 720, minHeight: 560)
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
