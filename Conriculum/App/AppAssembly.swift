import SwiftData

struct AppAssembly {
    let modelContainer: ModelContainer
    let curriculumClient: CurriculumClient
    let knowledgeCatalogClient: KnowledgeCatalogClient
    let learningRecordClient: LearningRecordClient
    let personalKnowledgeClient: PersonalKnowledgeClient

    static func live() throws -> Self {
        make(environment: try PersistenceEnvironmentRegistry.live())
    }

    static func inMemory() throws -> Self {
        make(environment: try PersistenceEnvironmentRegistry.makeInMemoryEnvironment())
    }

    private static func make(
        environment: PersistenceEnvironment
    ) -> Self {
        let contentStore = BundledContentStore()
        return Self(
            modelContainer: environment.modelContainer,
            curriculumClient: .live(store: contentStore),
            knowledgeCatalogClient: .live(store: contentStore),
            learningRecordClient: .live(store: environment.userDataStore),
            personalKnowledgeClient: .live(store: environment.userDataStore)
        )
    }
}
