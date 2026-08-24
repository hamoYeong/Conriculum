import SwiftData

struct AppAssembly {
    let modelContainer: ModelContainer

    static func live() throws -> Self {
        Self(modelContainer: try PersistenceContainerFactory.live())
    }

    static func inMemory() throws -> Self {
        Self(modelContainer: try PersistenceContainerFactory.inMemory())
    }
}
