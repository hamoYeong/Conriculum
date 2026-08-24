import SwiftData

struct PersistenceEnvironment: Sendable {
    let modelContainer: ModelContainer
    let userDataStore: UserDataStore
}

@MainActor
enum PersistenceEnvironmentRegistry {
    private static let liveResult: Result<PersistenceEnvironment, Error> = Result {
        let modelContainer = try PersistenceContainerFactory.live()
        return PersistenceEnvironment(
            modelContainer: modelContainer,
            userDataStore: UserDataStore(modelContainer: modelContainer)
        )
    }

    private static let previewResult: Result<PersistenceEnvironment, Error> = Result {
        try makeInMemoryEnvironment()
    }

    private static let testResult: Result<PersistenceEnvironment, Error> = Result {
        try makeInMemoryEnvironment()
    }

    static func live() throws -> PersistenceEnvironment {
        try liveResult.get()
    }

    static func preview() throws -> PersistenceEnvironment {
        try previewResult.get()
    }

    static func test() throws -> PersistenceEnvironment {
        try testResult.get()
    }

    static func makeInMemoryEnvironment() throws -> PersistenceEnvironment {
        let modelContainer = try PersistenceContainerFactory.inMemory()
        return PersistenceEnvironment(
            modelContainer: modelContainer,
            userDataStore: UserDataStore(modelContainer: modelContainer)
        )
    }
}
