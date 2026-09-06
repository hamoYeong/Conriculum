import Foundation

struct V2ContentValidator: Sendable {
    func validate(manifest: V2ContentManifest) throws {
        guard manifest.schemaVersion == 1 else {
            throw V2ContentError.unsupportedSchema(manifest.schemaVersion)
        }
        guard manifest.contentVersion == .v2 else {
            throw V2ContentError.wrongVersion(manifest.contentVersion)
        }

        var ids = Set<String>()
        try register(manifest.id, in: &ids)
        try validateOrders(manifest.stages.map(\.order), path: "stages")

        for stage in manifest.stages {
            try register(stage.id, in: &ids)
            try validateOrders(stage.chapters.map(\.order), path: "\(stage.id).chapters")
            for chapter in stage.chapters {
                guard chapter.stageID == stage.id else {
                    throw V2ContentError.invalidReference("\(chapter.id).stageID")
                }
                try register(chapter.id, in: &ids)
                try validateOrders(chapter.pages.map(\.order), path: "\(chapter.id).pages")
                guard chapter.pages.isEmpty == false else {
                    throw V2ContentError.invalidReference("\(chapter.id).pages")
                }
                for page in chapter.pages {
                    try register(page.id, in: &ids)
                    guard page.resource.hasPrefix("Content/v2/learning/") else {
                        throw V2ContentError.invalidReference("\(page.id).resource")
                    }
                }
            }
        }
    }

    func validate(page: V2LearningPage, reference: V2PageReference) throws {
        guard page.schemaVersion == 1 else {
            throw V2ContentError.unsupportedSchema(page.schemaVersion)
        }
        guard page.contentVersion == .v2 else {
            throw V2ContentError.wrongVersion(page.contentVersion)
        }
        guard page.id == reference.id, page.order == reference.order else {
            throw V2ContentError.invalidReference("\(reference.id).pageIdentity")
        }
        try validateOrders(page.blocks.map(\.order), path: "\(page.id).blocks")
        let blockIDs = Set(page.blocks.map(\.id))
        guard blockIDs.count == page.blocks.count else {
            throw V2ContentError.duplicateID("\(page.id).blocks")
        }
        for termRef in page.termRefs where !blockIDs.contains(termRef.anchor.blockID) {
            throw V2ContentError.invalidReference("\(termRef.id).anchor.blockID")
        }
    }

    private func register(_ id: String, in ids: inout Set<String>) throws {
        guard ids.insert(id).inserted else { throw V2ContentError.duplicateID(id) }
    }

    private func validateOrders(_ orders: [Int], path: String) throws {
        let expected = orders.isEmpty ? [] : Array(1...orders.count)
        guard orders.sorted() == expected else {
            throw V2ContentError.invalidOrder(path)
        }
    }
}
