import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        switch store.route {
        case .home:
            VStack(spacing: 16) {
                Text("Conriculum")
                    .font(.largeTitle)
                Text("학습 홈")
                    .foregroundStyle(.secondary)
                Button("Chapter 2 열기") {
                    store.send(.chapterRequested(id: AppFeature.chapter02ID))
                }
            }
            .frame(minWidth: 720, minHeight: 480)

        case let .learningWorkspace(chapterID):
            VStack(spacing: 16) {
                Text("학습 워크스페이스")
                    .font(.largeTitle)
                Text(chapterID)
                    .foregroundStyle(.secondary)
                Button("Home으로 돌아가기") {
                    store.send(.homeRequested)
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
