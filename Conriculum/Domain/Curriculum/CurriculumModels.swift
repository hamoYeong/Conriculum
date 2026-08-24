struct LearningPath: Codable, Equatable, Sendable {
    let id: LearningPathID
    let title: String
    let stages: [Stage]
}

struct Stage: Codable, Equatable, Sendable {
    let id: StageID
    let pathID: LearningPathID
    let order: Int
    let title: String
    let chapters: [Chapter]
}

struct Chapter: Codable, Equatable, Sendable {
    let id: ChapterID
    let stageID: StageID
    let order: Int
    let title: String
    let summary: String
    let overview: LearningPage
    let pages: [LearningPage]

    var progressPages: [LearningPage] {
        pages
            .filter { $0.kind == .lesson }
            .sorted {
                ($0.order ?? .max, $0.id.rawValue) < ($1.order ?? .max, $1.id.rawValue)
            }
    }

    var progressPageIDs: [LearningPageID] {
        progressPages.map(\.id)
    }

    var progressDenominator: Int {
        progressPages.count
    }

    var allPages: [LearningPage] {
        [overview] + pages
    }

    func page(id: LearningPageID) -> LearningPage? {
        allPages.first { $0.id == id }
    }
}

struct LearningPage: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Equatable, Sendable {
        case overview
        case lesson
    }

    let id: LearningPageID
    let kind: Kind
    let order: Int?
    let title: String
    let goal: String
    let sections: [LearningSection]
    let activities: [LearningActivity]
    let knowledgeLinks: [LearningKnowledgeLink]
    let knowledgeContext: PageKnowledgeContext
}

struct LearningSection: Codable, Equatable, Sendable {
    let id: LearningSectionID
    let order: Int
    let title: String?
    let activityID: LearningActivityID?
}

struct LearningActivity: Codable, Equatable, Sendable {
    let id: LearningActivityID
    let sectionID: LearningSectionID
    let isRequired: Bool
}

struct LearningKnowledgeLink: Codable, Equatable, Sendable {
    let conceptID: KnowledgeConceptID
    let role: KnowledgeLinkRole
    let usage: String
    let displayTiming: String?
}

struct PageKnowledgeContext: Codable, Equatable, Sendable {
    let currentlyUsedConceptIDs: [KnowledgeConceptID]
    let currentlyUsedSummary: String
    let changedKnowledgeSummary: String
    let nearbyKnowledge: [NearbyKnowledgeContext]
    let refreshTriggers: [String]
    let emptyStateMessage: String
    let focusModeSummary: String
}

struct NearbyKnowledgeContext: Codable, Equatable, Sendable {
    let conceptID: KnowledgeConceptID
    let reason: String
}
