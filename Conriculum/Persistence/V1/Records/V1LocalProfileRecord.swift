import Foundation
import SwiftData

@Model
final class LocalProfileRecord {
    #Index<LocalProfileRecord>([\.lastOpenedAt])

    @Attribute(.unique) var id: String
    var createdAt: Date
    var lastOpenedAt: Date

    init(
        id: String,
        createdAt: Date,
        lastOpenedAt: Date
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
    }
}
