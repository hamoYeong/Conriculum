import ComposableArchitecture
import SwiftUI

struct ChapterLearningView: View {
    let store: StoreOf<ChapterLearningFeature>

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            content
        }
        .navigationTitle(store.chapter?.title ?? "Chapter 2")
        .frame(minWidth: 480, minHeight: 520)
        .task {
            guard store.chapter == nil else { return }
            await store.send(.task).finish()
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading, store.chapter == nil {
            ProgressView("학습 페이지를 불러오는 중…")
                .controlSize(.large)
        } else if let message = store.loadErrorMessage, store.chapter == nil {
            ContentUnavailableView {
                Label(
                    "학습 페이지를 불러오지 못했습니다",
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(message)
            } actions: {
                Button("다시 불러오기") {
                    store.send(.task)
                }
            }
        } else if store.isShowingCompletionSummary {
            completionSummary
        } else if let page = store.currentPage {
            learningPage(page)
        } else {
            ContentUnavailableView(
                "표시할 학습 페이지가 없습니다",
                systemImage: "doc.questionmark",
                description: Text("Chapter 2 지도에서 다시 시작해 주세요.")
            )
        }
    }

    private func learningPage(_ page: LearningPage) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(pageEyebrow(page))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(page.title)
                            .font(.largeTitle.weight(.bold))
                            .accessibilityHeading(.h1)

                        Text(page.goal)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()

                    ContentUnavailableView {
                        Label(
                            page.kind == .overview
                                ? "학습 경로가 준비되었습니다"
                                : "학습 블록이 준비되었습니다",
                            systemImage: page.kind == .overview
                                ? "map"
                                : "square.stack.3d.up"
                        )
                    } description: {
                        Text(
                            page.kind == .overview
                                ? "전체 경로를 확인한 뒤 첫 페이지에서 학습을 시작합니다."
                                : "이 페이지의 학습 블록 \(page.sections.count)개는 다음 구현 단계에서 표시합니다."
                        )
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 36)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            }

            navigationBar(for: page)
        }
    }

    private func navigationBar(for page: LearningPage) -> some View {
        VStack(spacing: 0) {
            if let message = store.navigationErrorMessage {
                Label(
                    "학습 기록을 저장하지 못했습니다. \(message)",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.callout)
                .foregroundStyle(.red)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.06))
            }

            Divider()

            HStack(spacing: 16) {
                if page.kind == .overview {
                    Spacer()
                    Button("학습 시작") {
                        store.send(.startButtonTapped)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("이전") {
                        store.send(.previousButtonTapped)
                    }
                    .disabled(
                        !store.canNavigatePrevious
                            || store.isSavingNavigation
                    )

                    Spacer()

                    if let position = store.progressPosition,
                       let count = store.chapter?.progressDenominator {
                        Text("\(position) / \(count)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("학습 페이지 \(count)개 중 \(position)번째")
                    }

                    Spacer()

                    Button(store.isLastPage ? "완료 요약" : "다음") {
                        store.send(.nextButtonTapped)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }

                if store.isSavingNavigation {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("학습 기록 저장 중")
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .background(.bar)
        .disabled(store.isSavingNavigation)
    }

    private var completionSummary: some View {
        ContentUnavailableView {
            Label(
                "Chapter 2 학습 경로를 모두 확인했습니다",
                systemImage: "checkmark.circle"
            )
        } description: {
            Text(
                "페이지 이동 기록은 저장했습니다. 실제 완료 여부는 저장된 활동과 학습 증거를 바탕으로 다음 단계에서 판단합니다."
            )
        }
        .frame(maxWidth: 680)
        .accessibilityLabel(
            "Chapter 2 완료 요약. 페이지 이동 기록을 저장했습니다."
        )
    }

    private func pageEyebrow(_ page: LearningPage) -> String {
        guard page.kind == .lesson,
              let position = store.progressPosition,
              let count = store.chapter?.progressDenominator
        else { return "Chapter 2 · 학습 지도" }
        return "Chapter 2 · \(position) / \(count)"
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
