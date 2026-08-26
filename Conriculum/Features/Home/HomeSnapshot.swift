import Foundation

struct HomeSnapshot: Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case empty
        case previewFixture(disclosure: String)
        case recorded
    }

    struct StageSummary: Equatable, Sendable {
        let title: String
        let goal: String
    }

    struct ChapterCard: Equatable, Sendable {
        let chapterID: ChapterID
        let title: String
        let summary: String
        let startPageID: LearningPageID
        let resumePageID: LearningPageID?
        let lastPage: PageSummary?
        let accessNote: String?
    }

    struct PageSummary: Equatable, Sendable {
        let id: LearningPageID
        let order: Int?
        let title: String
    }

    struct ActivitySummary: Equatable, Sendable {
        let id: LearningActivityID
        let pageID: LearningPageID
        let pageTitle: String
        let sectionTitle: String?
        let occurredAt: Date
    }

    struct EvidenceSummary: Equatable, Sendable {
        let kind: LearningEvidenceKind
        let count: Int
        let latestAt: Date?
    }

    let source: Source
    let stage: StageSummary
    let chapter: ChapterCard
    let lastActivity: ActivitySummary?
    let evidence: [EvidenceSummary]
    let knowledgeChanges: KnowledgeChangeCollection
    let knowledgeChangesEmptyStateMessage: String
}

extension HomeSnapshot.StageSummary {
    static let stageOne = Self(
        title: "Stage 1 · Swift로 문제를 표현할 준비",
        goal: "컴퓨팅 사고력을 얻기 위해 Swift를 도구로 사용할 준비를 마친다."
    )
}
