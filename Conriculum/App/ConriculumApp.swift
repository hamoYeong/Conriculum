import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct ConriculumApp: App {
    private let assembly: AppAssembly
    private let store: StoreOf<AppFeature>

    init() {
        let assembly: AppAssembly
        do {
            assembly = try .live()
        } catch {
            fatalError("Failed to create the app persistence container: \(error)")
        }
        self.assembly = assembly

        store = Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.v1CurriculumClient = assembly.v1CurriculumClient
            $0.v1KnowledgeCatalogClient = assembly.v1KnowledgeCatalogClient
            $0.v1LearningRecordClient = assembly.v1LearningRecordClient
            $0.v1PersonalKnowledgeClient = assembly.v1PersonalKnowledgeClient
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .modelContainer(assembly.modelContainer)
        }
        .commands {
            SidebarCommands()
        }
    }
}
