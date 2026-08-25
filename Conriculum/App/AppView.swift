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
            VStack(spacing: 16) {
                Text("학습 워크스페이스")
                    .font(.largeTitle)
                Text(chapterID.rawValue)
                    .foregroundStyle(.secondary)
                Text(
                    store.workspace?.chapter.currentPageID.rawValue
                        ?? "페이지를 준비하는 중"
                )
                    .foregroundStyle(.secondary)
                Button("Home으로 돌아가기") {
                    store.send(.workspace(.homeButtonTapped))
                }
            }
            .frame(minWidth: 720, minHeight: 480)
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
