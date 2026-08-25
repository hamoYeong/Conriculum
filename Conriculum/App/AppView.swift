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

        case .learningWorkspace:
            if let workspaceStore = store.scope(
                state: \.workspace,
                action: \.workspace
            ) {
                LearningWorkspaceView(store: workspaceStore)
            } else {
                ProgressView("학습 워크스페이스를 준비하는 중입니다.")
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
