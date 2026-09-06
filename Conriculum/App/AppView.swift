import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        switch store.route {
        case .home:
            HomeView(
                store: store.scope(state: \.home, action: \.home)
            )

        case let .learningWorkspace(chapterID):
            if let workspaceStore = store.scope(
                state: \.workspace,
                action: \.workspace
            ) {
                LearningWorkspaceView(store: workspaceStore)
                    .id(chapterID)
            } else {
                ProgressView("학습 워크스페이스를 준비하는 중입니다.")
                    .frame(minWidth: 720, minHeight: 560)
            }

        case let .v2Learning(pageID):
            if let v2LearningStore = store.scope(
                state: \.v2Learning,
                action: \.v2Learning
            ) {
                V2LearningView(store: v2LearningStore)
                    .id(pageID)
            } else {
                ProgressView("ver.2 학습 화면을 준비하는 중입니다.")
                    .frame(minWidth: 720, minHeight: 560)
            }

        case .knowledgeSystem:
            if let knowledgeSystemStore = store.scope(
                state: \.knowledgeSystem,
                action: \.knowledgeSystem
            ) {
                KnowledgeSystemView(store: knowledgeSystemStore)
            } else {
                ProgressView("지식 체계를 준비하는 중입니다.")
                    .frame(minWidth: 720, minHeight: 560)
            }
        }
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
