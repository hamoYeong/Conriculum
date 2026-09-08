import Foundation
import Testing

@testable import Conriculum

@MainActor
struct DependencyClientTests {
    @Test
    func selectedVersionDefaultsToCurrentAndRestoresExplicitChoice() async throws {
        let suite = try #require(UserDefaults(suiteName: UUID().uuidString))
        let client = ContentSettingsClient.live(store: suite)

        #expect(await client.loadSelectedVersion() == .v2)
        await client.saveSelectedVersion(.v1)
        #expect(await client.loadSelectedVersion() == .v1)
    }

    @Test
    func legacyProgressMigratesOnceWithoutDeletingItsSource() async throws {
        let suite = try #require(UserDefaults(suiteName: UUID().uuidString))
        let environment = try PersistenceEnvironmentRegistry.makeInMemoryEnvironment()
        let progress = CourseProgress(
            lastVisitedPageID: "v2.s2.c3.p4",
            completedPageIDs: ["v2.s1.c1.p1", "v2.s1.c1.p2"],
            activityResponses: [
                "activity-1": GameResponse(
                    activityID: "activity-1",
                    selectedOptionIDs: ["option-2"],
                    isCorrect: true,
                    attempts: 2,
                    answeredAt: Date(timeIntervalSince1970: 1_800_000_000)
                )
            ],
            supportLevelsByPageID: ["v2.s1.c1.p2": .hinted]
        )
        let legacyData = try JSONEncoder().encode(progress)
        suite.set(legacyData, forKey: "learning.progress.v2")
        let client = ProgressClient.live(
            store: environment.courseProgressStore,
            legacyStore: suite
        )

        #expect(try await client.load() == progress)
        #expect(try environment.courseProgressStore.load() == progress)
        #expect(suite.data(forKey: "learning.progress.v2") == legacyData)

        var updated = progress
        updated.lastVisitedPageID = "v2.s2.c4.p1"
        try await client.save(updated)

        #expect(try await client.load() == updated)
        #expect(suite.data(forKey: "learning.progress.v2") == legacyData)
        #expect(suite.object(forKey: "learning.progress.v1") == nil)
    }

    @Test
    func oldLegacyPayloadDefaultsMissingSupportLevels() throws {
        let data = Data(#"{"lastVisitedPageID":"v2.s1.c1.p1","completedPageIDs":[],"activityResponses":{}}"#.utf8)

        let progress = try JSONDecoder().decode(CourseProgress.self, from: data)

        #expect(progress.supportLevelsByPageID.isEmpty)
    }
}
