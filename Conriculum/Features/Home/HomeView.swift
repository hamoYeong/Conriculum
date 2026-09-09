import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    learningHome
                    knowledgeSystemCard
                }
                .frame(maxWidth: 1_080, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 600)
        .task {
            guard store.manifest == nil else { return }
            await store.send(.task).finish()
        }
    }

    @ViewBuilder
    private var learningHome: some View {
        if let manifest = store.manifest {
            VStack(alignment: .leading, spacing: 10) {
                Text("CONRICULUM · VER.2")
                    .font(.caption.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Text(manifest.title)
                    .font(.largeTitle.bold())
                    .accessibilityHeading(.h1)
                Text("코드를 게임처럼 알아보고, 의미 단위와 실행 흐름으로 읽는 독립형 과정입니다.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if let resumeChapter = resumeLearningChapter(in: manifest) {
                resumeLearningCard(resumeChapter, manifest: manifest)
            }

            HomeStagePager(
                manifest: manifest,
                progress: store.learningProgress,
                selectedStageID: store.selectedStageID,
                onStageSelected: { store.send(.stageSelected($0)) },
                onChapterSelected: { store.send(.learningChapterSelected($0)) }
            )
        } else if let message = store.contentLoadErrorMessage {
            ContentUnavailableView {
                Label("콘텐츠를 불러오지 못했습니다", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("다시 불러오기") { store.send(.reloadRequested) }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, minHeight: 360)
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("학습 지도를 불러오는 중입니다.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 360)
        }
    }

    private func resumeLearningChapter(in manifest: ContentManifest) -> LearningChapter? {
        if let pageID = store.learningProgress.lastVisitedPageID,
           let chapter = manifest.chapters.first(where: {
               $0.pages.contains { $0.id == pageID }
           }) {
            return chapter
        }
        return manifest.stages
            .sorted { $0.order < $1.order }
            .first?.chapters
            .sorted { $0.order < $1.order }
            .first
    }

    private func resumeLearningCard(
        _ chapter: LearningChapter,
        manifest: ContentManifest
    ) -> some View {
        let pageID = store.learningProgress.lastVisitedPageID.flatMap { pageID in
            chapter.pages.contains { $0.id == pageID } ? pageID : nil
        } ?? chapter.firstPageID
        let page = pageID.flatMap { manifest.pageReference(id: $0) }

        return VStack(alignment: .leading, spacing: 16) {
            Label(
                store.learningProgress.lastVisitedPageID == nil
                    ? "여기서 시작해 보세요"
                    : "이어서 학습하기",
                systemImage: "play.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(.tint)

            Text(chapter.title)
                .font(.title2.bold())
            if let page {
                VStack(alignment: .leading, spacing: 4) {
                    Text(page.title).font(.headline)
                    Text(page.goal)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Button(
                store.learningProgress.lastVisitedPageID == nil
                    ? "학습 시작"
                    : "이어보기"
            ) {
                store.send(.learningChapterSelected(chapter.id))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.accentColor.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
        }
    }

    private var knowledgeSystemCard: some View {
        Button {
            store.send(.knowledgeSystemButtonTapped)
        } label: {
            HStack(alignment: .center, spacing: 18) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 48, height: 48)
                    .background(
                        Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text("지식 책장 열기")
                        .font(.title3.weight(.semibold))
                    Text("학습에서 만난 지식과 연결된 개념을 다시 확인합니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.knowledge-bookshelf")
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityHint("지식 책장 화면을 엽니다.")
    }
}

#Preview("학습 홈") {
    HomeView(
        store: Store(initialState: HomeFeature.State()) {
            HomeFeature()
        }
    )
}
