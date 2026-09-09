import Foundation
import Testing

@testable import Conriculum

@MainActor
struct DependencyClientTests {
    @Test
    func progressClientLoadsAndSavesThroughTheStore() async throws {
        let environment = try PersistenceEnvironmentRegistry.makeInMemoryEnvironment()
        let progress = CourseProgress(
            lastVisitedPageID: "s2.c3.p4",
            completedPageIDs: ["s1.c1.p1", "s1.c1.p2"],
            activityResponses: [
                "activity-1": GameResponse(
                    activityID: "activity-1",
                    selectedOptionIDs: ["option-2"],
                    isCorrect: true,
                    attempts: 2,
                    answeredAt: Date(timeIntervalSince1970: 1_800_000_000)
                )
            ],
            supportLevelsByPageID: ["s1.c1.p2": .hinted]
        )
        let client = ProgressClient.live(store: environment.courseProgressStore)

        #expect(try await client.load() == .empty)
        try await client.save(progress)
        #expect(try environment.courseProgressStore.load() == progress)

        var updated = progress
        updated.lastVisitedPageID = "s2.c4.p1"
        try await client.save(updated)

        #expect(try await client.load() == updated)
    }

    @Test
    func payloadDefaultsMissingSupportLevels() throws {
        let data = Data(#"{"lastVisitedPageID":"s1.c1.p1","completedPageIDs":[],"activityResponses":{}}"#.utf8)

        let progress = try JSONDecoder().decode(CourseProgress.self, from: data)

        #expect(progress.supportLevelsByPageID.isEmpty)
    }
}
