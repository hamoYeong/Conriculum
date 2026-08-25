import ComposableArchitecture
import SwiftUI

struct KnowledgeContextView: View {
    let store: StoreOf<KnowledgeContextFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("지식 문맥", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.title2.weight(.semibold))
                    .accessibilityHeading(.h1)

                Text("현재 학습에 직접 쓰는 개념과 이번 학습으로 달라진 지식을 함께 확인합니다.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                ContentUnavailableView {
                    Label("연결된 지식을 준비하는 중", systemImage: "books.vertical")
                } description: {
                    Text("현재 페이지가 준비되면 관련 개념과 나의 지식 변화를 표시합니다.")
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            }
            .padding(20)
        }
        .navigationSplitViewColumnWidth(min: 230, ideal: 290, max: 360)
        .accessibilityLabel("현재 학습의 지식 문맥")
    }
}

#Preview("Knowledge Context") {
    KnowledgeContextView(
        store: Store(
            initialState: KnowledgeContextFeature.State(
                currentPageID: "chapter-02-overview"
            )
        ) {
            KnowledgeContextFeature()
        }
    )
    .frame(width: 300, height: 640)
}
