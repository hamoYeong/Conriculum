import SwiftData

struct V1PersistenceEnvironment: Sendable {
    let modelContainer: ModelContainer
    let userDataStore: V1UserDataStore
}

@MainActor
enum V1PersistenceEnvironmentRegistry {
    private static let liveResult: Result<V1PersistenceEnvironment, Error> = Result {
        let modelContainer = try V1PersistenceContainerFactory.live()
        return V1PersistenceEnvironment(
            modelContainer: modelContainer,
            userDataStore: V1UserDataStore(modelContainer: modelContainer)
        )
    }

    private static let previewResult: Result<V1PersistenceEnvironment, Error> = Result {
        try makeInMemoryEnvironment()
    }

    private static let testResult: Result<V1PersistenceEnvironment, Error> = Result {
        try makeInMemoryEnvironment()
    }

    static func live() throws -> V1PersistenceEnvironment {
        try liveResult.get()
    }

    static func preview() throws -> V1PersistenceEnvironment {
        try previewResult.get()
    }

    static func test() throws -> V1PersistenceEnvironment {
        try testResult.get()
    }

    static func makeInMemoryEnvironment() throws -> V1PersistenceEnvironment {
        let modelContainer = try V1PersistenceContainerFactory.inMemory()
        return V1PersistenceEnvironment(
            modelContainer: modelContainer,
            userDataStore: V1UserDataStore(modelContainer: modelContainer)
        )
    }
}
