import SwiftData

enum ConriculumPersistenceSchema {
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

enum PersistenceContainerFactory {
    static func live() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "Conriculum",
            schema: ConriculumPersistenceSchema.schema,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: ConriculumPersistenceSchema.schema,
            configurations: [configuration]
        )
    }

    static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "ConriculumInMemory",
            schema: ConriculumPersistenceSchema.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: ConriculumPersistenceSchema.schema,
            configurations: [configuration]
        )
    }
}
