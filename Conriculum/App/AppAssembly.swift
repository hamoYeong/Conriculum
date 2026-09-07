import SwiftData

struct AppAssembly {
    let modelContainer: ModelContainer
    let v1CurriculumClient: V1CurriculumClient
    let v1KnowledgeCatalogClient: V1KnowledgeCatalogClient
    let v1LearningRecordClient: V1LearningRecordClient
    let v1PersonalKnowledgeClient: V1PersonalKnowledgeClient

    static func live() throws -> Self {
        make(environment: try PersistenceEnvironmentRegistry.live())
    }

    static func inMemory() throws -> Self {
        make(environment: try PersistenceEnvironmentRegistry.makeInMemoryEnvironment())
    }

    private static func make(
        environment: PersistenceEnvironment
    ) -> Self {
        let contentStore = V1BundledContentStore()
        return Self(
            modelContainer: environment.modelContainer,
            v1CurriculumClient: .live(store: contentStore),
            v1KnowledgeCatalogClient: .live(store: contentStore),
            v1LearningRecordClient: .live(store: environment.userDataStore),
            v1PersonalKnowledgeClient: .live(store: environment.userDataStore)
        )
    }
}
