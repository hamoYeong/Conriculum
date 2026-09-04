import Foundation

/// Compatibility with progress saved before individual page visits were recorded.
enum LearningExposure {
    static func historicalPageIDs(chapter: Chapter, progress: LearningProgress?) -> Set<LearningPageID> {
        guard let progress, progress.chapterID == chapter.id else { return [] }
        let pages = chapter.progressPageIDs
        var result = Set(progress.completedPageIDs.filter(pages.contains))
        if let index = pages.firstIndex(of: progress.currentPageID) {
            result.formUnion(pages[...index])
        }
        return result
    }

    static func directConceptIDs(page: LearningPage) -> Set<KnowledgeConceptID> {
        guard page.kind == .lesson else { return [] }
        return Set(page.knowledgeLinks.compactMap {
            $0.role == .primary || $0.role == .supporting ? $0.conceptID : nil
        })
    }
}
