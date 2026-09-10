import SwiftData

struct AppAssembly {
    let modelContainer: ModelContainer

    static func live() throws -> Self {
        make(environment: try PersistenceEnvironmentRegistry.live())
    }

    static func inMemory() throws -> Self {
        make(environment: try PersistenceEnvironmentRegistry.makeInMemoryEnvironment())
    }

    private static func make(environment: PersistenceEnvironment) -> Self {
        Self(modelContainer: environment.modelContainer)
    }
}
