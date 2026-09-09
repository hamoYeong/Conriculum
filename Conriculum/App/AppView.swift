import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        switch store.route {
        case .home:
            HomeView(store: store.scope(state: \.home, action: \.home))

        case let .learning(pageID):
            if let learningStore = store.scope(
                state: \.learning,
                action: \.learning
            ) {
                LearningView(store: learningStore)
                    .id(pageID)
            } else {
                ProgressView("학습 화면을 준비하는 중입니다.")
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
