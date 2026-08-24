import ComposableArchitecture
import SwiftData
import SwiftUI

@main
struct ConriculumApp: App {
    private let assembly: AppAssembly
    private let store: StoreOf<AppFeature>

    init() {
        do {
            assembly = try .live()
        } catch {
            fatalError("Failed to create the app persistence container: \(error)")
        }

        store = Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
                .modelContainer(assembly.modelContainer)
        }
    }
}
