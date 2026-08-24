import Foundation

struct ContentValidator: Sendable {
    func validate(
        chapter: Chapter,
        catalog: KnowledgeCatalog,
        identityManifest: ContentIdentityManifest,
        chapterResource: String = "Curriculum/Stage01/Chapter02/chapter-02.json",
        catalogResource: String = "KnowledgeCatalog/values-and-types.json",
        identityResource: String = "ContentManifest/content-identity.json"
    ) throws {
        var issues: [ContentValidationIssue] = []

        validatePageStructure(chapter, resource: chapterResource, issues: &issues)
        validateCatalog(catalog, resource: catalogResource, issues: &issues)
        validateReferences(
            chapter: chapter,
            catalog: catalog,
            chapterResource: chapterResource,
            catalogResource: catalogResource,
            issues: &issues
        )
        validateIdentity(
            chapter: chapter,
            catalog: catalog,
            manifest: identityManifest,
            resource: identityResource,
            issues: &issues
        )

        if issues.isEmpty == false {
            throw ContentValidationError(issues: issues)
        }
    }

    private func validatePageStructure(
        _ chapter: Chapter,
        resource: String,
        issues: inout [ContentValidationIssue]
    ) {
        var pagePaths: [LearningPageID: String] = [:]
        var sectionPaths: [LearningSectionID: String] = [:]
        var activityPaths: [LearningActivityID: String] = [:]

        if chapter.overview.kind != .overview {
            issues.append(.init(resource: resource, fieldPath: "overview.kind", message: "must be overview"))
        }
        if chapter.overview.order != nil {
            issues.append(.init(resource: resource, fieldPath: "overview.order", message: "must be null"))
        }
        if chapter.pages.count != 8 {
            issues.append(.init(resource: resource, fieldPath: "pages", message: "must contain exactly 8 lesson pages"))
        }

        registerUnique(
            id: chapter.overview.id,
            fieldPath: "overview.id",
            seen: &pagePaths,
            resource: resource,
            kind: "page",
            issues: &issues
        )
        var overviewSectionOrders: [Int: String] = [:]
        for (sectionIndex, section) in chapter.overview.sections.enumerated() {
            let sectionPath = "overview.sections[\(sectionIndex)]"
            registerUnique(
                id: section.id,
                fieldPath: "\(sectionPath).id",
                seen: &sectionPaths,
                resource: resource,
                kind: "section",
                issues: &issues
            )
            registerUnique(
                id: section.order,
                fieldPath: "\(sectionPath).order",
                seen: &overviewSectionOrders,
                resource: resource,
                kind: "section order within \(chapter.overview.id.rawValue)",
                issues: &issues
            )
        }
        for (activityIndex, activity) in chapter.overview.activities.enumerated() {
            registerUnique(
                id: activity.id,
                fieldPath: "overview.activities[\(activityIndex)].id",
                seen: &activityPaths,
                resource: resource,
                kind: "activity",
                issues: &issues
            )
        }

        for (pageIndex, page) in chapter.pages.enumerated() {
            let pagePath = "pages[\(pageIndex)]"
            registerUnique(
                id: page.id,
                fieldPath: "\(pagePath).id",
                seen: &pagePaths,
                resource: resource,
                kind: "page",
                issues: &issues
            )

            if page.kind != .lesson {
                issues.append(.init(resource: resource, fieldPath: "\(pagePath).kind", message: "must be lesson"))
            }
            if page.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(resource: resource, fieldPath: "\(pagePath).goal", message: "must not be empty"))
            }
            if page.knowledgeLinks.isEmpty {
                issues.append(.init(resource: resource, fieldPath: "\(pagePath).knowledgeLinks", message: "must not be empty"))
            }
            if page.knowledgeContext.currentlyUsedConceptIDs.isEmpty {
                issues.append(.init(resource: resource, fieldPath: "\(pagePath).knowledgeContext.currentlyUsedConceptIDs", message: "must not be empty"))
            }
            if page.knowledgeContext.emptyStateMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(resource: resource, fieldPath: "\(pagePath).knowledgeContext.emptyStateMessage", message: "must not be empty"))
            }
            if page.knowledgeContext.focusModeSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(resource: resource, fieldPath: "\(pagePath).knowledgeContext.focusModeSummary", message: "must not be empty"))
            }
            if page.sections.contains(where: { $0.content.tag == .completionCheck }) == false {
                issues.append(.init(resource: resource, fieldPath: "\(pagePath).sections", message: "must contain a completionCheck section"))
            }

            var sectionOrders: [Int: String] = [:]
            for (sectionIndex, section) in page.sections.enumerated() {
                let sectionPath = "\(pagePath).sections[\(sectionIndex)]"
                registerUnique(
                    id: section.id,
                    fieldPath: "\(sectionPath).id",
                    seen: &sectionPaths,
                    resource: resource,
                    kind: "section",
                    issues: &issues
                )
                registerUnique(
                    id: section.order,
                    fieldPath: "\(sectionPath).order",
                    seen: &sectionOrders,
                    resource: resource,
                    kind: "section order within \(page.id.rawValue)",
                    issues: &issues
                )
            }

            for (activityIndex, activity) in page.activities.enumerated() {
                registerUnique(
                    id: activity.id,
                    fieldPath: "\(pagePath).activities[\(activityIndex)].id",
                    seen: &activityPaths,
                    resource: resource,
                    kind: "activity",
                    issues: &issues
                )
            }
        }

        let actualOrders = chapter.progressPages.compactMap(\.order)
        if actualOrders != Array(1...8) {
            issues.append(.init(resource: resource, fieldPath: "pages.order", message: "must contain each order from 1 through 8 exactly once"))
        }
        if chapter.progressDenominator != 8 || chapter.progressPageIDs.contains(chapter.overview.id) {
            issues.append(.init(resource: resource, fieldPath: "overview", message: "must be excluded from the progress denominator"))
        }
    }

    private func validateCatalog(
        _ catalog: KnowledgeCatalog,
        resource: String,
        issues: inout [ContentValidationIssue]
    ) {
        var conceptPaths: [KnowledgeConceptID: String] = [:]
        var relationPaths: [KnowledgeRelationID: String] = [:]

        for (index, concept) in catalog.concepts.enumerated() {
            registerUnique(
                id: concept.id,
                fieldPath: "concepts[\(index)].id",
                seen: &conceptPaths,
                resource: resource,
                kind: "concept",
                issues: &issues
            )
        }
        for (index, relation) in catalog.relations.enumerated() {
            registerUnique(
                id: relation.id,
                fieldPath: "relations[\(index)].id",
                seen: &relationPaths,
                resource: resource,
                kind: "relation",
                issues: &issues
            )
        }
    }

    private func validateReferences(
        chapter: Chapter,
        catalog: KnowledgeCatalog,
        chapterResource: String,
        catalogResource: String,
        issues: inout [ContentValidationIssue]
    ) {
        let conceptIDs = Set(catalog.concepts.map(\.id))
        let activityIDs = Set(chapter.allPages.flatMap(\.activities).map(\.id))

        for (relationIndex, relation) in catalog.relations.enumerated() {
            if conceptIDs.contains(relation.sourceConceptID) == false {
                issues.append(.init(
                    resource: catalogResource,
                    fieldPath: "relations[\(relationIndex)].sourceConceptID",
                    message: "does not resolve to a catalog concept"
                ))
            }
            if conceptIDs.contains(relation.targetConceptID) == false {
                issues.append(.init(
                    resource: catalogResource,
                    fieldPath: "relations[\(relationIndex)].targetConceptID",
                    message: "does not resolve to a catalog concept"
                ))
            }
        }

        let pageEntries = [(path: "overview", page: chapter.overview)]
            + chapter.pages.enumerated().map { (path: "pages[\($0.offset)]", page: $0.element) }

        for (pagePath, page) in pageEntries {
            let pageSectionIDs = Set(page.sections.map(\.id))
            let pageActivityIDs = Set(page.activities.map(\.id))

            for (activityIndex, activity) in page.activities.enumerated()
            where pageSectionIDs.contains(activity.sectionID) == false {
                issues.append(.init(
                    resource: chapterResource,
                    fieldPath: "\(pagePath).activities[\(activityIndex)].sectionID",
                    message: "does not resolve to a section on the same page"
                ))
            }

            for (linkIndex, link) in page.knowledgeLinks.enumerated()
            where conceptIDs.contains(link.conceptID) == false {
                issues.append(.init(
                    resource: chapterResource,
                    fieldPath: "\(pagePath).knowledgeLinks[\(linkIndex)].conceptID",
                    message: "does not resolve to a catalog concept"
                ))
            }

            let contextReferences = page.knowledgeContext.currentlyUsedConceptIDs
                + page.knowledgeContext.nearbyKnowledge.map(\.conceptID)
            for conceptID in contextReferences where conceptIDs.contains(conceptID) == false {
                issues.append(.init(
                    resource: chapterResource,
                    fieldPath: "\(pagePath).knowledgeContext",
                    message: "concept '\(conceptID.rawValue)' does not resolve to the catalog"
                ))
            }

            for (sectionIndex, section) in page.sections.enumerated() {
                let sectionPath = "\(pagePath).sections[\(sectionIndex)]"

                if let activityID = section.activityID, pageActivityIDs.contains(activityID) == false {
                    issues.append(.init(
                        resource: chapterResource,
                        fieldPath: "\(sectionPath).activityID",
                        message: "does not resolve to an activity on the same page"
                    ))
                }

                for conceptID in section.content.referencedConceptIDs
                where conceptIDs.contains(conceptID) == false {
                    issues.append(.init(
                        resource: chapterResource,
                        fieldPath: "\(sectionPath).content.payload",
                        message: "concept '\(conceptID.rawValue)' does not resolve to the catalog"
                    ))
                }

                for activityID in section.content.referencedActivityIDs
                where activityIDs.contains(activityID) == false {
                    issues.append(.init(
                        resource: chapterResource,
                        fieldPath: "\(sectionPath).content.payload.evidenceActivityIDs",
                        message: "activity '\(activityID.rawValue)' does not resolve"
                    ))
                }
            }
        }
    }

    private func validateIdentity(
        chapter: Chapter,
        catalog: KnowledgeCatalog,
        manifest: ContentIdentityManifest,
        resource: String,
        issues: inout [ContentValidationIssue]
    ) {
        var identityPaths: [String: String] = [:]

        for (index, identity) in manifest.identities.enumerated() {
            let key = "\(identity.kind.rawValue):\(identity.stableID)"
            registerUnique(
                id: key,
                fieldPath: "identities[\(index)].stableID",
                seen: &identityPaths,
                resource: resource,
                kind: "identity",
                issues: &issues
            )
        }

        let keys = Set(identityPaths.keys)
        requireIdentity(.stage, id: chapter.stageID.rawValue, keys: keys, resource: resource, issues: &issues)
        requireIdentity(.chapter, id: chapter.id.rawValue, keys: keys, resource: resource, issues: &issues)
        for page in chapter.allPages {
            requireIdentity(.page, id: page.id.rawValue, keys: keys, resource: resource, issues: &issues)
        }
        for concept in catalog.concepts {
            requireIdentity(.knowledgeConcept, id: concept.id.rawValue, keys: keys, resource: resource, issues: &issues)
        }
    }

    private func requireIdentity(
        _ kind: ContentIdentityKind,
        id: String,
        keys: Set<String>,
        resource: String,
        issues: inout [ContentValidationIssue]
    ) {
        guard keys.contains("\(kind.rawValue):\(id)") == false else { return }
        issues.append(.init(
            resource: resource,
            fieldPath: "identities",
            message: "missing \(kind.rawValue) identity for '\(id)'"
        ))
    }

    private func registerUnique<ID: Hashable>(
        id: ID,
        fieldPath: String,
        seen: inout [ID: String],
        resource: String,
        kind: String,
        issues: inout [ContentValidationIssue]
    ) {
        if let firstPath = seen[id] {
            issues.append(.init(
                resource: resource,
                fieldPath: fieldPath,
                message: "duplicate \(kind) ID; first declared at \(firstPath)"
            ))
        } else {
            seen[id] = fieldPath
        }
    }
}

struct ContentValidationError: Error, Sendable, CustomStringConvertible {
    let issues: [ContentValidationIssue]

    var description: String {
        issues.map(\.description).joined(separator: "\n")
    }
}

struct ContentValidationIssue: Equatable, Sendable, CustomStringConvertible {
    let resource: String
    let fieldPath: String
    let message: String

    var description: String {
        "\(resource):\(fieldPath): \(message)"
    }
}

private extension LearningSectionContent {
    var referencedConceptIDs: [KnowledgeConceptID] {
        switch self {
        case let .definition(content):
            [content.conceptID]
        case let .knowledgeLink(content):
            content.links.map(\.conceptID)
        case let .personalExpressionComparison(content):
            content.conceptIDs
        case let .enrichmentTask(content):
            content.conceptIDs
        case let .personalKnowledgePromotion(content):
            content.conceptIDs
        case let .personalKnowledgeRelation(content):
            content.sourceConceptIDs + content.targetConceptIDs
        default:
            []
        }
    }

    var referencedActivityIDs: [LearningActivityID] {
        switch self {
        case let .personalKnowledgePromotion(content):
            content.evidenceActivityIDs
        case let .personalKnowledgeRelation(content):
            content.evidenceActivityIDs
        default:
            []
        }
    }
}
