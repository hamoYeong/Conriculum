import ComposableArchitecture
import SwiftUI

struct V2LearningView: View {
    let store: StoreOf<V2LearningFeature>

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            content
        }
        .frame(minWidth: 720, minHeight: 600)
        .task {
            guard store.page == nil else { return }
            await store.send(.task).finish()
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading, store.page == nil {
            ProgressView("ver.2 학습 페이지를 불러오는 중…")
        } else if let message = store.loadErrorMessage, store.page == nil {
            ContentUnavailableView {
                Label("ver.2 페이지를 열 수 없습니다", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("다시 시도") { store.send(.task) }
                Button("홈으로") { store.send(.homeButtonTapped) }
            }
        } else if let page = store.page, let stage = store.stage {
            learningPage(page, stage: stage)
        }
    }

    private func learningPage(_ page: V2LearningPage, stage: V2Stage) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    store.send(.homeButtonTapped)
                } label: {
                    Label("홈", systemImage: "house")
                }
                Spacer()
                if let position = store.position {
                    Text("전체 \(position) / \(store.orderedPages.count)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.bar)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("STAGE \(stage.order) · CHAPTER \(store.chapter?.order ?? 0)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(page.title)
                            .font(.largeTitle.bold())
                            .accessibilityHeading(.h1)
                        Text(page.goal)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    if stage.kind == .game {
                        V2StageOneGameComponent(page: page)
                    } else {
                        V2StageTwoLearningComponent(page: page)
                    }
                }
                .frame(maxWidth: 820, alignment: .leading)
                .padding(32)
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 0) {
                if let message = store.saveErrorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }
                Divider()
                HStack {
                    Button("이전", systemImage: "chevron.left") {
                        store.send(.previousButtonTapped)
                    }
                    .disabled(!store.canGoPrevious || store.isSaving)
                    Spacer()
                    if store.progress.completedPageIDs.contains(page.id) {
                        Label("완료", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Button(
                        store.isLastPage ? "학습 완료" : "완료하고 다음",
                        systemImage: store.isLastPage ? "checkmark" : "chevron.right"
                    ) {
                        store.send(.nextButtonTapped)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isSaving)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            }
            .background(.bar)
        }
    }
}
