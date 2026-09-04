import ComposableArchitecture
import SwiftUI

/// 실제 Chapter 4 JSON을 공용 renderer로 조립해 콘텐츠와 상호작용을 함께 점검한다.
private struct ChapterFourLearningPreview: View {
    let pageID: LearningPageID

    var body: some View {
        if let chapter = try? BundledContentStore().loadChapter("chapter-04"),
           let catalog = try? BundledContentStore().loadCatalog() {
            ChapterLearningView(
                store: Store(initialState: state(chapter: chapter, catalog: catalog)) {
                    ChapterLearningFeature()
                } withDependencies: {
                    $0.learningRecordClient = .previewValue
                }
            )
        } else {
            ContentUnavailableView("Chapter 4 콘텐츠를 확인해 주세요", systemImage: "doc.questionmark")
        }
    }

    private func state(chapter: Chapter, catalog: KnowledgeCatalog) -> ChapterLearningFeature.State {
        var state = ChapterLearningFeature.State(chapterID: chapter.id, currentPageID: pageID)
        state.chapter = chapter
        state.knowledgeCatalog = catalog
        return state
    }
}

#Preview("Chapter 4 · 학습 지도") {
    ChapterFourLearningPreview(pageID: "chapter-04-overview")
        .frame(width: 760, height: 900)
}

#Preview("Chapter 4 · 조건 조합 · 좁은 본문") {
    ChapterFourLearningPreview(pageID: "chapter-04-page-05")
        .frame(width: 480, height: 800)
}

#Preview("Chapter 4 · 의미 단위 조각 읽기") {
    ChapterFourLearningPreview(pageID: "chapter-04-page-09")
        .frame(width: 760, height: 900)
}
