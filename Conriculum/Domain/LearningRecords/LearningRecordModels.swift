import Foundation

struct CourseProgress: Codable, Equatable, Sendable {
    var lastVisitedPageID: String?
    var completedPageIDs: Set<String>
    var activityResponses: [String: GameResponse]
    var supportLevelsByPageID: [String: LearningSupportLevel]

    init(
        lastVisitedPageID: String?,
        completedPageIDs: Set<String>,
        activityResponses: [String: GameResponse] = [:],
        supportLevelsByPageID: [String: LearningSupportLevel] = [:]
    ) {
        self.lastVisitedPageID = lastVisitedPageID
        self.completedPageIDs = completedPageIDs
        self.activityResponses = activityResponses
        self.supportLevelsByPageID = supportLevelsByPageID
    }

    private enum CodingKeys: String, CodingKey {
        case lastVisitedPageID
        case completedPageIDs
        case activityResponses
        case supportLevelsByPageID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastVisitedPageID = try container.decodeIfPresent(
            String.self,
            forKey: .lastVisitedPageID
        )
        completedPageIDs = try container.decodeIfPresent(
            Set<String>.self,
            forKey: .completedPageIDs
        ) ?? []
        activityResponses = try container.decodeIfPresent(
            [String: GameResponse].self,
            forKey: .activityResponses
        ) ?? [:]
        supportLevelsByPageID = try container.decodeIfPresent(
            [String: LearningSupportLevel].self,
            forKey: .supportLevelsByPageID
        ) ?? [:]
    }

    nonisolated static let empty = Self(
        lastVisitedPageID: nil,
        completedPageIDs: [],
        activityResponses: [:],
        supportLevelsByPageID: [:]
    )
}

enum LearningSupportLevel: String, Codable, CaseIterable, Equatable, Sendable {
    case guided
    case hinted
    case independent
}

struct GameResponse: Codable, Equatable, Sendable {
    let activityID: String
    let selectedOptionIDs: Set<String>
    let matches: [String: String]
    let isCorrect: Bool
    let attempts: Int
    let answeredAt: Date

    init(
        activityID: String,
        selectedOptionIDs: Set<String> = [],
        matches: [String: String] = [:],
        isCorrect: Bool,
        attempts: Int,
        answeredAt: Date
    ) {
        self.activityID = activityID
        self.selectedOptionIDs = selectedOptionIDs
        self.matches = matches
        self.isCorrect = isCorrect
        self.attempts = attempts
        self.answeredAt = answeredAt
    }

    private enum CodingKeys: String, CodingKey {
        case activityID, selectedOptionIDs, selectedOptionID, matches
        case isCorrect, attempts, answeredAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activityID = try container.decode(String.self, forKey: .activityID)
        selectedOptionIDs = try container.decodeIfPresent(
            Set<String>.self,
            forKey: .selectedOptionIDs
        ) ?? container.decodeIfPresent(String.self, forKey: .selectedOptionID).map { [$0] } ?? []
        matches = try container.decodeIfPresent(
            [String: String].self,
            forKey: .matches
        ) ?? [:]
        isCorrect = try container.decode(Bool.self, forKey: .isCorrect)
        attempts = try container.decode(Int.self, forKey: .attempts)
        answeredAt = try container.decode(Date.self, forKey: .answeredAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activityID, forKey: .activityID)
        try container.encode(selectedOptionIDs, forKey: .selectedOptionIDs)
        try container.encode(matches, forKey: .matches)
        try container.encode(isCorrect, forKey: .isCorrect)
        try container.encode(attempts, forKey: .attempts)
        try container.encode(answeredAt, forKey: .answeredAt)
    }
}
