import SwiftData

enum V1PersistenceSchema {
    static let modelTypes: [any PersistentModel.Type] = [
        LocalProfileRecord.self,
        LearningProgressRecord.self,
        ActivityResponseRecord.self,
        LearningEvidenceRecord.self,
        PersonalConceptRevisionRecord.self,
        PersonalKnowledgeRelationRecord.self,
    ]

    static let schema = Schema(modelTypes)
}

enum V1PersistenceContainerFactory {
    static func live() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Conriculum",
            schema: V1PersistenceSchema.schema,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: V1PersistenceSchema.schema,
            configurations: [configuration]
        )
    }

    static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "ConriculumInMemory",
            schema: V1PersistenceSchema.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: V1PersistenceSchema.schema,
            configurations: [configuration]
        )
    }
}
