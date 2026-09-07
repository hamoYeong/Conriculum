import ComposableArchitecture
import Foundation

struct CourseProgress: Codable, Equatable, Sendable {
    var lastVisitedPageID: String?
    var completedPageIDs: Set<String>
    var activityResponses: [String: GameResponse]

    init(
        lastVisitedPageID: String?,
        completedPageIDs: Set<String>,
        activityResponses: [String: GameResponse] = [:]
    ) {
        self.lastVisitedPageID = lastVisitedPageID
        self.completedPageIDs = completedPageIDs
        self.activityResponses = activityResponses
    }

    private enum CodingKeys: String, CodingKey {
        case lastVisitedPageID
        case completedPageIDs
        case activityResponses
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
    }

    nonisolated static let empty = Self(
        lastVisitedPageID: nil,
        completedPageIDs: [],
        activityResponses: [:]
    )
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

@DependencyClient
struct ProgressClient: Sendable {
    var load: @Sendable () async throws -> CourseProgress = { .empty }
    var save: @Sendable (_ progress: CourseProgress) async throws -> Void
}

extension ProgressClient: DependencyKey {
    static let liveValue = Self.live(store: .standard)
}

extension ProgressClient: TestDependencyKey {
    static let previewValue = Self()
    static let testValue = Self()
}

extension ProgressClient {
    static func live(store: UserDefaults) -> Self {
        let storage = ProgressStorage(store: store)
        return Self(
            load: { try storage.load() },
            save: { try storage.save($0) }
        )
    }
}

extension DependencyValues {
    var progressClient: ProgressClient {
        get { self[ProgressClient.self] }
        set { self[ProgressClient.self] = newValue }
    }
}

private final class ProgressStorage: @unchecked Sendable {
    private let store: UserDefaults
    private let key = "learning.progress.v2"
    private let lock = NSLock()

    init(store: UserDefaults) {
        self.store = store
    }

    func load() throws -> CourseProgress {
        try lock.withLock {
            guard let data = store.data(forKey: key) else { return .empty }
            return try JSONDecoder().decode(CourseProgress.self, from: data)
        }
    }

    func save(_ progress: CourseProgress) throws {
        let data = try JSONEncoder().encode(progress)
        lock.withLock { store.set(data, forKey: key) }
    }
}
