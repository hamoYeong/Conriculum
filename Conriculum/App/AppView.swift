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

        case let .v1Learning(chapterID):
            if let workspaceStore = store.scope(
                state: \.v1Workspace,
                action: \.v1Workspace
            ) {
                V1LearningWorkspaceView(store: workspaceStore)
                    .id(chapterID)
            } else {
                ProgressView("학습 워크스페이스를 준비하는 중입니다.")
                    .frame(minWidth: 720, minHeight: 560)
            }

        case let .learning(pageID):
            if let learningStore = store.scope(
                state: \.learning,
                action: \.learning
            ) {
                LearningView(store: learningStore)
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
