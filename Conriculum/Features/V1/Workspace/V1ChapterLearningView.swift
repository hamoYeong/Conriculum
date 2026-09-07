import ComposableArchitecture
import SwiftUI

struct V1ChapterLearningView: View {
    let store: StoreOf<V1ChapterLearningFeature>

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            content
        }
        .navigationTitle(chapterTitle)
        .frame(minWidth: 240, minHeight: 520)
        .onChange(of: store.currentPage?.id, initial: true) { _, pageID in
            if pageID != nil { store.send(.pagePresented) }
        }
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
                description: Text("챕터 지도에서 다시 시작해 주세요.")
            )
        }
    }

    private func learningPage(_ page: V1LearningPage) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    Color.clear
                        .frame(height: 0)
                        .id(ScrollAnchor.top)

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

                        if let message = store.visitErrorMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("열람 기록을 저장하지 못했습니다. \(message)")
                                    .font(.caption).foregroundStyle(.red)
                                Button("열람 기록 다시 저장") { store.send(.pagePresented) }
                            }
                        }

                        if let chapter = store.chapter,
                           V1LearningContentAssembly.isAssembled(page) {
                            V1LearningPageContentView(
                                chapter: chapter,
                                page: page,
                                store: store
                            )
                        } else {
                            ContentUnavailableView {
                                Label(
                                    "학습 블록을 조립하는 중",
                                    systemImage: "square.stack.3d.up"
                                )
                            } description: {
                                Text(
                                    "이 페이지의 타입화된 학습 블록을 공용 컴포넌트에 연결하고 있습니다."
                                )
                            }
                            .frame(maxWidth: .infinity, minHeight: 260)
                        }
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: page.id) {
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
            .disabled(store.isSavingNavigation)

            navigationBar(for: page)
        }
    }

    private func navigationBar(for page: V1LearningPage) -> some View {
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
                "\(chapterLabel) 학습 경로를 모두 확인했습니다",
                systemImage: "checkmark.circle"
            )
        } description: {
            Text(
                "여기까지의 입력과 이동 기록을 저장했습니다. 다음 챕터의 학습 지도에서 이어질 질문을 확인해 보세요."
            )
        } actions: {
            if let chapter = store.chapter,
               let destination = chapter.progressPages.last?.navigation.next,
               chapter.page(id: destination.pageID) == nil {
                Button("다음 챕터로 · \(destination.label)") {
                    store.send(.nextChapterButtonTapped)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isSavingNavigation)
            }
            if let message = store.navigationErrorMessage {
                Text(message).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: 680)
        .accessibilityLabel(
            "\(chapterLabel) 완료 요약. 페이지 이동 기록을 저장했습니다."
        )
    }

    private func pageEyebrow(_ page: V1LearningPage) -> String {
        guard page.kind == .lesson,
              let position = store.progressPosition,
              let count = store.chapter?.progressDenominator
        else { return "\(chapterLabel) · 학습 지도" }
        return "\(chapterLabel) · \(position) / \(count)"
    }

    private var chapterLabel: String {
        guard let chapter = store.chapter else { return "챕터" }
        return "Chapter \(chapter.order)"
    }

    private var chapterTitle: String {
        guard let chapter = store.chapter else { return "학습 챕터" }
        return "Chapter \(chapter.order) · \(chapter.title)"
    }

    private enum ScrollAnchor: Hashable {
        case top
    }
}

#Preview("챕터 학습") {
    V1ChapterLearningView(
        store: Store(
            initialState: V1ChapterLearningFeature.State(
                chapterID: "chapter-02",
                currentPageID: "chapter-02-overview"
            )
        ) {
            V1ChapterLearningFeature()
        }
    )
    .frame(width: 720, height: 640)
}
