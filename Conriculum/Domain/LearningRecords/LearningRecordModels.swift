import Foundation

struct LearningProgress: Codable, Equatable, Sendable {
    let chapterID: ChapterID
    var currentPageID: LearningPageID
    var completedPageIDs: Set<LearningPageID>
    var updatedAt: Date
}

struct ActivityResponse: Codable, Equatable, Sendable {
    let id: ActivityResponseID
    let activityID: LearningActivityID
    let pageID: LearningPageID
    let fields: [ActivityResponseField]
    let recordedAt: Date
}

struct ActivityResponseField: Codable, Equatable, Sendable {
    let key: String
    let values: [String]
}

struct LearningEvidence: Codable, Equatable, Sendable {
    let id: LearningEvidenceID
    let kind: LearningEvidenceKind
    let pageID: LearningPageID
    let activityID: LearningActivityID?
    let responseID: ActivityResponseID?
    let note: String?
    let recordedAt: Date
}

enum LearningEvidenceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case viewed
    case activityAttempt
    case assistedSuccess
    case independentSuccess
    case reasoningExplanation
    case conceptLink
}
