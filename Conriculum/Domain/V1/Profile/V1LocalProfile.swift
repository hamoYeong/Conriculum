import Foundation

struct V1LocalProfile: Codable, Equatable, Sendable {
    let id: LocalProfileID
    let createdAt: Date
    var lastOpenedAt: Date
}
