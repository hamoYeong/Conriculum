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
            $0.curriculumClient = assembly.curriculumClient
            $0.knowledgeCatalogClient = assembly.knowledgeCatalogClient
            $0.learningRecordClient = assembly.learningRecordClient
            $0.personalKnowledgeClient = assembly.personalKnowledgeClient
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
