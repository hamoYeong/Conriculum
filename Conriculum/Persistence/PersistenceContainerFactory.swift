import Foundation
import SwiftData

enum PersistenceSchema {
    static let modelTypes: [any PersistentModel.Type] = [
        CourseProgressRecord.self,
        PageProgressRecord.self,
        GameResponseRecord.self,
    ]

    static let schema = Schema(modelTypes)
}

enum PersistenceContainerFactory {
    static func live() throws -> ModelContainer {
        try make(configuration: ModelConfiguration(
            "ConriculumCurrent",
            schema: PersistenceSchema.schema,
            cloudKitDatabase: .none
        ))
    }

    static func inMemory() throws -> ModelContainer {
        try make(configuration: ModelConfiguration(
            "ConriculumCurrentInMemory",
            schema: PersistenceSchema.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        ))
    }

    static func fileBacked(at url: URL) throws -> ModelContainer {
        try make(configuration: ModelConfiguration(
            "ConriculumCurrent",
            schema: PersistenceSchema.schema,
            url: url,
            cloudKitDatabase: .none
        ))
    }

    private static func make(
        configuration: ModelConfiguration
    ) throws -> ModelContainer {
        try ModelContainer(
            for: PersistenceSchema.schema,
            configurations: [configuration]
        )
    }
}
