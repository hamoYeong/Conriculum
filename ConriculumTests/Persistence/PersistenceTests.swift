import Foundation
import SwiftData
import Testing
@testable import Conriculum

@MainActor
struct PersistenceTests {
    private let firstDate = Date(timeIntervalSince1970: 1_800_000_000)
    private let secondDate = Date(timeIntervalSince1970: 1_800_086_400)

    @Test
    func currentSchemaIsPhysicallySeparateFromV1() {
        let currentNames = Set(PersistenceSchema.schema.entities.map(\.name))
        let v1Names = Set(V1PersistenceSchema.schema.entities.map(\.name))

        #expect(currentNames == [
            "CourseProgressRecord",
            "PageProgressRecord",
            "GameResponseRecord",
        ])
        #expect(currentNames.isDisjoint(with: v1Names))
    }

    @Test
    func progressRoundTripsAndSynchronizesRemovedChildren() throws {
        let environment = try PersistenceEnvironmentRegistry.makeInMemoryEnvironment()
        let store = CourseProgressStore(
            modelContainer: environment.modelContainer,
            now: { self.firstDate }
        )
        let original = fixture(at: firstDate)

        try store.save(original)
        #expect(try store.load() == original)

        let retainedResponse = try #require(original.activityResponses["v2.s1.c1.game.2"])
        let updated = CourseProgress(
            lastVisitedPageID: "v2.s1.c1.p3",
            completedPageIDs: ["v2.s1.c1.p2"],
            activityResponses: [retainedResponse.activityID: retainedResponse],
            supportLevelsByPageID: ["v2.s1.c1.p2": .hinted]
        )
        try store.save(updated)

        #expect(try store.load() == updated)

        let context = ModelContext(environment.modelContainer)
        #expect(try context.fetchCount(FetchDescriptor<CourseProgressRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PageProgressRecord>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<GameResponseRecord>()) == 1)
    }

    @Test
    func fileBackedProgressRecoversAfterRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appending(
            path: "ConriculumCurrentPersistence-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Current.store")
        let progress = fixture(at: firstDate)

        try write(progress, to: url)
        let recovered = try read(from: url)

        #expect(recovered == progress)
    }

    @Test
    func failedSaveRollsBackAndPreservesLastSuccess() throws {
        let container = try PersistenceContainerFactory.inMemory()
        let failure = SaveFailureController()
        let store = CourseProgressStore(
            modelContainer: container,
            now: { self.firstDate },
            saveContext: { context in
                if failure.shouldFail { throw StubSaveError() }
                try context.save()
            }
        )
        let original = fixture(at: firstDate)
        try store.save(original)

        failure.shouldFail = true
        do {
            try store.save(CourseProgress(
                lastVisitedPageID: "v2.s2.c1.p1",
                completedPageIDs: [],
                activityResponses: [:]
            ))
            Issue.record("강제로 실패시킨 현재 진행 저장이 성공했다.")
        } catch let error as PersistenceClientError {
            guard case let .saveFailed(operation, _) = error else {
                Issue.record("예상하지 못한 Persistence 오류: \(error)")
                return
            }
            #expect(operation == "courseProgress.save")
        } catch {
            Issue.record("식별할 수 없는 저장 오류: \(error)")
        }

        let relaunchedStore = CourseProgressStore(modelContainer: container)
        #expect(try relaunchedStore.load() == original)
    }

    @Test
    func corruptResponsePayloadReportsItsRecordAndField() throws {
        let container = try PersistenceContainerFactory.inMemory()
        let context = ModelContext(container)
        context.insert(try CourseProgressRecord(
            contentVersion: .v2,
            lastVisitedPageID: "v2.s1.c1.p1",
            updatedAt: firstDate
        ))
        context.insert(GameResponseRecord(
            id: GameResponseRecord.storageID(
                contentVersion: .v2,
                activityID: "v2.s1.c1.game.1"
            ),
            contentVersion: ContentVersion.v2.rawValue,
            activityID: "v2.s1.c1.game.1",
            selectedOptionIDs: ["option.1"],
            matchesPayload: Data("not-json".utf8),
            isCorrect: true,
            attempts: 1,
            answeredAt: firstDate
        ))
        try context.save()

        do {
            _ = try CourseProgressStore(modelContainer: container).load()
            Issue.record("손상된 게임 응답이 복원되었다.")
        } catch let error as PersistenceClientError {
            guard case let .invalidStoredData(record, fieldPath, _) = error else {
                Issue.record("예상하지 못한 Persistence 오류: \(error)")
                return
            }
            #expect(record == "GameResponseRecord")
            #expect(fieldPath == "matchesPayload")
        } catch {
            Issue.record("식별할 수 없는 로드 오류: \(error)")
        }
    }

    private func fixture(at date: Date) -> CourseProgress {
        CourseProgress(
            lastVisitedPageID: "v2.s1.c1.p2",
            completedPageIDs: ["v2.s1.c1.p1", "v2.s1.c1.p2"],
            activityResponses: [
                "v2.s1.c1.game.1": GameResponse(
                    activityID: "v2.s1.c1.game.1",
                    selectedOptionIDs: ["option.2"],
                    isCorrect: true,
                    attempts: 2,
                    answeredAt: date
                ),
                "v2.s1.c1.game.2": GameResponse(
                    activityID: "v2.s1.c1.game.2",
                    matches: ["pair.1": "pair.1", "pair.2": "pair.2"],
                    isCorrect: true,
                    attempts: 1,
                    answeredAt: date
                ),
            ],
            supportLevelsByPageID: [
                "v2.s1.c1.p1": .guided,
                "v2.s1.c1.p2": .independent,
            ]
        )
    }

    private func write(_ progress: CourseProgress, to url: URL) throws {
        let container = try PersistenceContainerFactory.fileBacked(at: url)
        try CourseProgressStore(modelContainer: container).save(progress)
    }

    private func read(from url: URL) throws -> CourseProgress? {
        let container = try PersistenceContainerFactory.fileBacked(at: url)
        return try CourseProgressStore(modelContainer: container).load()
    }
}

private final class SaveFailureController {
    var shouldFail = false
}

private struct StubSaveError: Error {}
