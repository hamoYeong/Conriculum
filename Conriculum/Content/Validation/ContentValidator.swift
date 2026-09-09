import Foundation

struct ContentValidator: Sendable {
    func validate(manifest: ContentManifest) throws {
        guard manifest.schemaVersion == 1 else {
            throw ContentError.unsupportedSchema(manifest.schemaVersion)
        }
        guard manifest.contentVersion == .v2 else {
            throw ContentError.wrongVersion(manifest.contentVersion)
        }

        var ids = Set<String>()
        try register(manifest.id, in: &ids)
        try validateOrders(manifest.stages.map(\.order), path: "stages")

        for stage in manifest.stages {
            try register(stage.id, in: &ids)
            try validateOrders(stage.chapters.map(\.order), path: "\(stage.id).chapters")
            for chapter in stage.chapters {
                guard chapter.stageID == stage.id else {
                    throw ContentError.invalidReference("\(chapter.id).stageID")
                }
                try register(chapter.id, in: &ids)
                try validateOrders(chapter.pages.map(\.order), path: "\(chapter.id).pages")
                guard chapter.pages.isEmpty == false else {
                    throw ContentError.invalidReference("\(chapter.id).pages")
                }
                for page in chapter.pages {
                    try register(page.id, in: &ids)
                    guard page.resource.hasPrefix("Content/learning/") else {
                        throw ContentError.invalidReference("\(page.id).resource")
                    }
                }
            }
        }
    }

    func validate(page: LessonPage, reference: PageReference) throws {
        guard page.schemaVersion == 1 else {
            throw ContentError.unsupportedSchema(page.schemaVersion)
        }
        guard page.contentVersion == .v2 else {
            throw ContentError.wrongVersion(page.contentVersion)
        }
        guard page.id == reference.id, page.order == reference.order else {
            throw ContentError.invalidReference("\(reference.id).pageIdentity")
        }
        try validateOrders(page.blocks.map(\.order), path: "\(page.id).blocks")
        let blockIDs = Set(page.blocks.map(\.id))
        guard blockIDs.count == page.blocks.count else {
            throw ContentError.duplicateID("\(page.id).blocks")
        }
        for termRef in page.termRefs where !blockIDs.contains(termRef.anchor.blockID) {
            throw ContentError.invalidReference("\(termRef.id).anchor.blockID")
        }
        var activityIDs = Set<String>()
        var optionIDs = Set<String>()
        for block in page.blocks {
            if block.kind == .wordSystem {
                guard let wordSystem = block.wordSystem,
                      wordSystem.entries.isEmpty == false,
                      Set(wordSystem.entries.map(\.id)).count == wordSystem.entries.count,
                      block.markdown.isEmpty
                else {
                    throw ContentError.invalidReference("\(block.id).wordSystem")
                }
            } else if block.wordSystem != nil {
                throw ContentError.invalidReference("\(block.id).wordSystem")
            }
            if block.kind == .unlock {
                guard let unlock = block.knowledgeUnlock,
                      unlock.cards.isEmpty == false,
                      Set(unlock.cards.map(\.id)).count == unlock.cards.count,
                      unlock.completionCriteria.isEmpty == false,
                      unlock.beginnerHint.isEmpty == false,
                      unlock.advancedTip.isEmpty == false,
                      block.markdown.isEmpty
                else {
                    throw ContentError.invalidReference("\(block.id).knowledgeUnlock")
                }
            } else if block.knowledgeUnlock != nil {
                throw ContentError.invalidReference("\(block.id).knowledgeUnlock")
            }
            if page.stageID == "v2.s1",
               block.kind == .game || block.kind == .boss,
               block.activities.isEmpty {
                throw ContentError.invalidReference("\(block.id).activities")
            }
            for activity in block.activities {
                try register(activity.id, in: &activityIDs)
                if activity.kind == .matching {
                    guard activity.options.isEmpty,
                          activity.correctOptionIDs.isEmpty,
                          activity.pairs.count >= 2,
                          Set(activity.pairs.map(\.id)).count == activity.pairs.count
                    else {
                        throw ContentError.invalidReference("\(activity.id).pairs")
                    }
                } else {
                    guard activity.pairs.isEmpty, activity.options.count >= 2 else {
                        throw ContentError.invalidReference("\(activity.id).options")
                    }
                    let localOptionIDs = Set(activity.options.map(\.id))
                    guard localOptionIDs.count == activity.options.count,
                          !activity.correctOptionIDs.isEmpty,
                          activity.correctOptionIDs.isSubset(of: localOptionIDs),
                          activity.kind != .singleChoice || activity.correctOptionIDs.count == 1
                    else {
                        throw ContentError.invalidReference(
                            "\(activity.id).correctOptionIDs"
                        )
                    }
                    for optionID in localOptionIDs {
                        try register(optionID, in: &optionIDs)
                    }
                }
            }
        }
    }

    func validate(
        catalog: KnowledgeCatalog,
        manifest: ContentManifest
    ) throws {
        guard catalog.schemaVersion == 1 else {
            throw ContentError.unsupportedSchema(catalog.schemaVersion)
        }

        var ids = Set<String>()
        try register(catalog.id, in: &ids)
        try validateOrders(catalog.collections.map(\.order), path: "collections")

        let conceptIDs = Set(catalog.concepts.map { $0.id.rawValue })
        guard conceptIDs.count == catalog.concepts.count else {
            throw ContentError.duplicateID("concepts")
        }
        var membershipCount = Dictionary(
            uniqueKeysWithValues: conceptIDs.map { ($0, 0) }
        )
        for collection in catalog.collections {
            try register(collection.id.rawValue, in: &ids)
            guard Set(collection.conceptIDs).count == collection.conceptIDs.count
            else {
                throw ContentError.duplicateID(
                    "\(collection.id.rawValue).conceptIDs"
                )
            }
            for conceptID in collection.conceptIDs {
                guard conceptIDs.contains(conceptID.rawValue) else {
                    throw ContentError.invalidReference(
                        "\(collection.id.rawValue).conceptIDs"
                    )
                }
                membershipCount[conceptID.rawValue, default: 0] += 1
            }
        }
        guard membershipCount.values.allSatisfy({ $0 == 1 }) else {
            throw ContentError.invalidReference("concepts.collectionMembership")
        }

        let chaptersByID = Dictionary(
            uniqueKeysWithValues: manifest.chapters.map { ($0.id, $0) }
        )
        for concept in catalog.concepts {
            var pageIDs = Set<String>()
            for reference in concept.revisitPages ?? [] {
                guard pageIDs.insert(reference.pageID.rawValue).inserted else {
                    throw ContentError.duplicateID(
                        "\(concept.id.rawValue).revisitPages"
                    )
                }
                guard let chapter = chaptersByID[
                    reference.chapterID.rawValue
                ],
                    chapter.order == reference.chapterOrder,
                    chapter.title == reference.chapterTitle,
                    let page = chapter.pages.first(where: {
                        $0.id == reference.pageID.rawValue
                    }),
                    page.order == reference.pageOrder,
                    page.title == reference.pageTitle
                else {
                    throw ContentError.invalidReference(
                        "\(concept.id.rawValue).revisitPages"
                    )
                }
            }
        }

        var directedEdges = Set<String>()
        for relation in catalog.relations {
            try register(relation.id.rawValue, in: &ids)
            let sourceID = relation.sourceConceptID.rawValue
            let targetID = relation.targetConceptID.rawValue
            guard sourceID != targetID,
                  conceptIDs.contains(sourceID),
                  conceptIDs.contains(targetID)
            else {
                throw ContentError.invalidReference(
                    "\(relation.id.rawValue).conceptIDs"
                )
            }
            let edge = "\(sourceID)->\(targetID)"
            let reverseEdge = "\(targetID)->\(sourceID)"
            guard !directedEdges.contains(edge),
                  !directedEdges.contains(reverseEdge)
            else {
                throw ContentError.invalidReference(
                    "\(relation.id.rawValue).direction"
                )
            }
            directedEdges.insert(edge)
        }
    }

    private func register(_ id: String, in ids: inout Set<String>) throws {
        guard ids.insert(id).inserted else { throw ContentError.duplicateID(id) }
    }

    private func validateOrders(_ orders: [Int], path: String) throws {
        let expected = orders.isEmpty ? [] : Array(1...orders.count)
        guard orders.sorted() == expected else {
            throw ContentError.invalidOrder(path)
        }
    }
}
