import ComposableArchitecture
import SwiftUI

struct ChapterLearningView: View {
    let store: StoreOf<ChapterLearningFeature>

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            ContentUnavailableView {
                Label("학습 페이지를 준비하고 있습니다", systemImage: "doc.text")
            } description: {
                Text("Chapter 2의 현재 페이지 내용을 불러와 이 영역에 표시합니다.")
            }
            .frame(maxWidth: 680)
            .accessibilityLabel(
                "Chapter 2 학습 페이지를 준비하고 있습니다."
            )
        }
        .navigationTitle("Chapter 2")
        .frame(minWidth: 480, minHeight: 520)
    }
}

#Preview("Chapter Learning") {
    ChapterLearningView(
        store: Store(
            initialState: ChapterLearningFeature.State(
                chapterID: Chapter02.id,
                currentPageID: "chapter-02-overview"
            )
        ) {
            ChapterLearningFeature()
        }
    )
    .frame(width: 720, height: 640)
}
