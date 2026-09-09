import SwiftData

struct PersistenceEnvironment: Sendable {
    let modelContainer: ModelContainer
    let courseProgressStore: CourseProgressStore
}

@MainActor
enum PersistenceEnvironmentRegistry {
    private static let liveResult: Result<PersistenceEnvironment, Error> = Result {
        let modelContainer = try PersistenceContainerFactory.live()
        return PersistenceEnvironment(
            modelContainer: modelContainer,
            courseProgressStore: CourseProgressStore(modelContainer: modelContainer)
        )
    }

    static func live() throws -> PersistenceEnvironment {
        try liveResult.get()
    }

    static func makeInMemoryEnvironment() throws -> PersistenceEnvironment {
        let modelContainer = try PersistenceContainerFactory.inMemory()
        return PersistenceEnvironment(
            modelContainer: modelContainer,
            courseProgressStore: CourseProgressStore(modelContainer: modelContainer)
        )
    }
}
