import ComposableArchitecture
import Foundation

@DependencyClient
struct ContentSettingsClient: Sendable {
    var loadSelectedVersion: @Sendable () async -> ContentVersion = { .v1 }
    var saveSelectedVersion: @Sendable (_ version: ContentVersion) async -> Void
}

extension ContentSettingsClient: DependencyKey {
    static let liveValue = Self.live(store: .standard)
}

extension ContentSettingsClient: TestDependencyKey {
    static let previewValue = Self()
    static let testValue = Self()
}

extension ContentSettingsClient {
    static func live(store: UserDefaults) -> Self {
        let storage = ContentSettingsStorage(store: store)
        return Self(
            loadSelectedVersion: { storage.loadSelectedVersion() },
            saveSelectedVersion: { storage.saveSelectedVersion($0) }
        )
    }
}

extension DependencyValues {
    var contentSettingsClient: ContentSettingsClient {
        get { self[ContentSettingsClient.self] }
        set { self[ContentSettingsClient.self] = newValue }
    }
}

private final class ContentSettingsStorage: @unchecked Sendable {
    private let store: UserDefaults
    private let key = "learning.content.selected-version"
    private let lock = NSLock()

    init(store: UserDefaults) {
        self.store = store
    }

    func loadSelectedVersion() -> ContentVersion {
        lock.withLock {
            store.string(forKey: key).flatMap(ContentVersion.init(rawValue:)) ?? .v1
        }
    }

    func saveSelectedVersion(_ version: ContentVersion) {
        lock.withLock { store.set(version.rawValue, forKey: key) }
    }
}
