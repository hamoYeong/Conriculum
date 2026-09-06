import Foundation
import Testing

@testable import Conriculum

struct V2DependencyClientTests {
    @Test
    func selectedVersionDefaultsToV1AndRestoresExplicitChoice() async throws {
        let suite = try #require(UserDefaults(suiteName: UUID().uuidString))
        let client = ContentSettingsClient.live(store: suite)

        #expect(await client.loadSelectedVersion() == .v1)
        await client.saveSelectedVersion(.v2)
        #expect(await client.loadSelectedVersion() == .v2)
    }

    @Test
    func v2ProgressRoundTripsWithoutTouchingV1Records() async throws {
        let suite = try #require(UserDefaults(suiteName: UUID().uuidString))
        let client = V2ProgressClient.live(store: suite)
        let progress = V2Progress(
            lastVisitedPageID: "v2.s2.c3.p4",
            completedPageIDs: ["v2.s1.c1.p1", "v2.s1.c1.p2"],
            activityResponses: [
                "activity-1": V2GameResponse(
                    activityID: "activity-1",
                    selectedOptionIDs: ["option-2"],
                    isCorrect: true,
                    attempts: 2,
                    answeredAt: Date(timeIntervalSince1970: 1_800_000_000)
                )
            ]
        )

        try await client.save(progress)

        #expect(try await client.load() == progress)
        #expect(suite.object(forKey: "learning.progress.v1") == nil)
    }
}
