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
                Button(
                    store.home.chapterEntry?.resumePageID == nil
                        ? "Chapter 2 시작하기"
                        : "Chapter 2 이어하기"
                ) {
                    if store.home.chapterEntry?.resumePageID == nil {
                        store.send(.home(.startButtonTapped))
                    } else {
                        store.send(.home(.resumeButtonTapped))
                    }
                }
                .disabled(store.home.chapterEntry == nil)

                if let loadErrorMessage = store.home.loadErrorMessage {
                    Text(loadErrorMessage)
                        .foregroundStyle(.red)
                }
            }
            .frame(minWidth: 720, minHeight: 480)
            .task {
                await store.send(.home(.task)).finish()
            }

        case let .learningWorkspace(chapterID, pageID):
            VStack(spacing: 16) {
                Text("학습 워크스페이스")
                    .font(.largeTitle)
                Text(chapterID.rawValue)
                    .foregroundStyle(.secondary)
                Text(pageID.rawValue)
                    .foregroundStyle(.secondary)
                Button("Home으로 돌아가기") {
                    store.send(.workspaceHomeButtonTapped)
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
