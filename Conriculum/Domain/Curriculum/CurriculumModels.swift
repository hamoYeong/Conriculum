// MARK: - 학습 체계: Path → Stage → Chapter → Page → Section

/// 전체 학습 경로. 여러 학습 단계를 소유하는 최상위 containment 값이다.
struct LearningPath: Codable, Equatable, Sendable {
    let id: LearningPathID
    let title: String
    let stages: [Stage]
}

/// 학습 경로 안의 한 단계. `pathID`로 부모를 명시하고 `order`로 표시 순서를 정한다.
struct Stage: Codable, Equatable, Sendable {
    let id: StageID
    let pathID: LearningPathID
    let order: Int
    let title: String
    let chapters: [Chapter]
}

/// 한 Chapter의 개요와 실제 진도 page를 함께 묶는 단위.
/// `overview`는 탐색에는 포함되지만 진도 계산에서는 제외한다.
struct Chapter: Codable, Equatable, Sendable {
    let id: ChapterID
    let stageID: StageID
    let order: Int
    let title: String
    let summary: String
    let overview: LearningPage
    let pages: [LearningPage]

    /// lesson만 골라 `order`로 정렬한다. 배열 위치가 진도 순서를 결정하지 않는다.
    var progressPages: [LearningPage] {
        pages
            .filter { $0.kind == .lesson }
            .sorted {
                ($0.order ?? .max, $0.id.rawValue) < ($1.order ?? .max, $1.id.rawValue)
            }
    }

    /// 외부 진도 상태가 배열 index 대신 stable page ID를 저장하도록 제공한다.
    var progressPageIDs: [LearningPageID] {
        progressPages.map(\.id)
    }

    /// 개요를 제외한 실제 lesson 수를 진도 분모로 사용한다.
    var progressDenominator: Int {
        progressPages.count
    }

    /// 탐색과 validation이 개요와 lesson 전체를 같은 방식으로 순회하게 한다.
    var allPages: [LearningPage] {
        [overview] + pages
    }

    /// 리소스 배열의 현재 배치와 무관하게 stable ID로 page를 찾는다.
    func page(id: LearningPageID) -> LearningPage? {
        allPages.first { $0.id == id }
    }
}

/// 사용자에게 한 화면으로 제시되는 학습 단위.
/// 표시할 section, 기록할 activity, 지식 문맥, stable-ID navigation을 한곳에 조립한다.
struct LearningPage: Codable, Equatable, Sendable {
    /// 개요와 실제 lesson의 진도 의미를 구분한다.
    enum Kind: String, Codable, Equatable, Sendable {
        case overview
        case lesson
    }

    let id: LearningPageID
    let kind: Kind
    /// overview는 `nil`, lesson은 Chapter 안에서의 진도 순서를 가진다.
    let order: Int?
    let title: String
    let goal: String
    let sections: [LearningSection]
    let activities: [LearningActivity]
    let knowledgeLinks: [LearningKnowledgeLink]
    let knowledgeContext: PageKnowledgeContext
    let navigation: LearningPageNavigation
}

/// 화면 안의 콘텐츠 block.
/// `content`는 표시 schema, `activityID`는 응답을 남길 별도 활동과의 연결이다.
struct LearningSection: Codable, Equatable, Sendable {
    let id: LearningSectionID
    let order: Int
    let title: String?
    let activityID: LearningActivityID?
    let content: LearningSectionContent
}

/// 학습자가 실제 행동이나 응답을 남기는 단위.
/// Section 표시 identity와 학습 기록 identity를 분리한다.
struct LearningActivity: Codable, Equatable, Sendable {
    let id: LearningActivityID
    let sectionID: LearningSectionID
    let isRequired: Bool
}

/// Page가 특정 지식 개념을 어떤 역할과 맥락으로 사용하는지 나타내는 연결.
struct LearningKnowledgeLink: Codable, Equatable, Sendable {
    let conceptID: KnowledgeConceptID
    let role: KnowledgeLinkRole
    let usage: String
    let displayTiming: String?
}

/// 지식 자체가 아니라, 현재 Page의 지식 UI가 보여 줄 사용·변화·인접 문맥이다.
struct PageKnowledgeContext: Codable, Equatable, Sendable {
    let currentlyUsedConceptIDs: [KnowledgeConceptID]
    let currentlyUsedSummary: String
    let changedKnowledgeSummary: String
    let nearbyKnowledge: [NearbyKnowledgeContext]
    let refreshTriggers: [String]
    let emptyStateMessage: String
    let focusModeSummary: String
}

/// 인접한 개념의 ID와 지금 함께 보여 주는 이유를 묶는다.
struct NearbyKnowledgeContext: Codable, Equatable, Sendable {
    let conceptID: KnowledgeConceptID
    let reason: String
}

/// 이전·다음 이동을 배열 index가 아닌 stable page ID로 연결한다.
struct LearningPageNavigation: Codable, Equatable, Sendable {
    let previous: LearningPageDestination?
    let next: LearningPageDestination?
}

/// 이동 대상과 사용자에게 표시할 label을 함께 보존한다.
struct LearningPageDestination: Codable, Equatable, Sendable {
    let pageID: LearningPageID
    let label: String
}

// MARK: - 다음 읽기: ConriculumTests/Domain/CurriculumModelsTests.swift
