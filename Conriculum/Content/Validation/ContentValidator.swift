import Foundation

// MARK: - 18. decode된 세 resource 사이의 의미 계약 검사

/// JSON 형태 검사가 끝난 Domain 값들을 서로 대조하는 validator.
/// Decoder가 “각 값의 모양”을 책임진다면, 이 타입은 ID·순서·참조·identity의 “관계”를 책임진다.
struct ContentValidator: Sendable {
    /// 모든 검사를 실행해 발견한 문제를 한 번에 모은다.
    /// 콘텐츠 작성자가 한 번의 실행으로 여러 잘못된 field를 함께 고칠 수 있게 fail-fast하지 않는다.
    func validate(
        chapter: Chapter,
        catalog: KnowledgeCatalog,
        identityManifest: ContentIdentityManifest,
        chapterResource: String? = nil,
        catalogResource: String = "KnowledgeCatalog/values-and-types.json",
        identityResource: String = "ContentManifest/content-identity.json"
    ) throws {
        var issues: [ContentValidationIssue] = []
        let resolvedChapterResource = chapterResource
            ?? "\(chapter.id.rawValue).json"

        validatePageStructure(
            chapter,
            resource: resolvedChapterResource,
            issues: &issues
        )
        validateCatalog(catalog, resource: catalogResource, issues: &issues)
        validateReferences(
            chapter: chapter,
            catalog: catalog,
            chapterResource: resolvedChapterResource,
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

    // MARK: Chapter 내부 구조

    /// overview/lesson 구분, 연속 order, ID 중복, 필수 문맥과 완료 section을 검사한다.
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
        if chapter.pages.isEmpty {
            issues.append(.init(
                resource: resource,
                fieldPath: "pages",
                message: "must contain at least one lesson page"
            ))
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
        if chapter.overview.sections.contains(
            where: { $0.content.tag == .learningCompass }
        ) == false {
            issues.append(.init(
                resource: resource,
                fieldPath: "overview.sections",
                message: "must contain a learningCompass section"
            ))
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
            if page.knowledgeContext.currentlyUsedConceptIDs.count > 3 {
                issues.append(.init(
                    resource: resource,
                    fieldPath: "\(pagePath).knowledgeContext.currentlyUsedConceptIDs",
                    message: "must contain one core concept and at most two supporting concepts"
                ))
            }
            if page.knowledgeContext.emptyStateMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(resource: resource, fieldPath: "\(pagePath).knowledgeContext.emptyStateMessage", message: "must not be empty"))
            }
            if page.knowledgeContext.focusModeSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(resource: resource, fieldPath: "\(pagePath).knowledgeContext.focusModeSummary", message: "must not be empty"))
            }
            if page.sections.contains(where: { $0.content.tag == .learningCompass }) == false {
                issues.append(.init(resource: resource, fieldPath: "\(pagePath).sections", message: "must contain a learningCompass section"))
            }
            let closureOrder = page.sections.first(
                where: { $0.content.tag == .learningClosure }
            )?.order
            if closureOrder == nil {
                issues.append(.init(resource: resource, fieldPath: "\(pagePath).sections", message: "must contain a learningClosure section"))
            }
            let optionalTags: Set<LearningSectionTag> = [
                .enrichmentTask,
                .personalKnowledgePromotion,
                .personalKnowledgeRelation,
                .knowledgeChangeSummary,
            ]
            if let closureOrder, page.sections.contains(where: {
                optionalTags.contains($0.content.tag)
                    && $0.order < closureOrder
            }) {
                issues.append(.init(
                    resource: resource,
                    fieldPath: "\(pagePath).sections",
                    message: "optional learning and personalization must follow learningClosure"
                ))
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
        let expectedOrders = Array(1..<(chapter.progressPages.count + 1))
        if actualOrders != expectedOrders {
            issues.append(.init(
                resource: resource,
                fieldPath: "pages.order",
                message: "must contain each order from 1 through \(chapter.progressPages.count) exactly once"
            ))
        }
        if chapter.progressDenominator != chapter.pages.count
            || chapter.progressPageIDs.contains(chapter.overview.id)
        {
            issues.append(.init(resource: resource, fieldPath: "overview", message: "must be excluded from the progress denominator"))
        }
    }

    // MARK: Catalog 내부 구조

    /// Collection·Concept·Relation ID와 Collection의 Concept 소속 계약을 검사한다.
    private func validateCatalog(
        _ catalog: KnowledgeCatalog,
        resource: String,
        issues: inout [ContentValidationIssue]
    ) {
        var collectionPaths: [KnowledgeCollectionID: String] = [:]
        var collectionOrderPaths: [Int: String] = [:]
        var conceptPaths: [KnowledgeConceptID: String] = [:]
        var relationPaths: [KnowledgeRelationID: String] = [:]
        var collectionMembershipPaths: [KnowledgeConceptID: String] = [:]

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

        let conceptIDs = Set(catalog.concepts.map(\.id))
        for (collectionIndex, collection) in catalog.collections.enumerated() {
            let collectionPath = "collections[\(collectionIndex)]"
            registerUnique(
                id: collection.id,
                fieldPath: "\(collectionPath).id",
                seen: &collectionPaths,
                resource: resource,
                kind: "collection",
                issues: &issues
            )
            registerUnique(
                id: collection.order,
                fieldPath: "\(collectionPath).order",
                seen: &collectionOrderPaths,
                resource: resource,
                kind: "collection order",
                issues: &issues
            )
            if collection.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(
                    resource: resource,
                    fieldPath: "\(collectionPath).title",
                    message: "must not be empty"
                ))
            }
            if collection.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(
                    resource: resource,
                    fieldPath: "\(collectionPath).summary",
                    message: "must not be empty"
                ))
            }
            if collection.systemImage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(
                    resource: resource,
                    fieldPath: "\(collectionPath).systemImage",
                    message: "must not be empty"
                ))
            }

            for (conceptIndex, conceptID) in collection.conceptIDs.enumerated() {
                let conceptPath = "\(collectionPath).conceptIDs[\(conceptIndex)]"
                if conceptIDs.contains(conceptID) == false {
                    issues.append(.init(
                        resource: resource,
                        fieldPath: conceptPath,
                        message: "does not resolve to a catalog concept"
                    ))
                }
                registerUnique(
                    id: conceptID,
                    fieldPath: conceptPath,
                    seen: &collectionMembershipPaths,
                    resource: resource,
                    kind: "collection membership for concept",
                    issues: &issues
                )
            }
        }

        for (index, concept) in catalog.concepts.enumerated()
        where collectionMembershipPaths[concept.id] == nil {
            issues.append(.init(
                resource: resource,
                fieldPath: "concepts[\(index)].id",
                message: "must appear in exactly one collection"
            ))
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

    // MARK: Resource 간 참조 무결성

    /// Relation·Page·Section payload가 가리키는 Concept/Activity가 실제로 존재하는지 검사한다.
    /// Activity ↔ Section 연결은 같은 Page 안에서만 유효하다는 경계도 여기서 강제한다.
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

    // MARK: 원본 문서 identity 추적

    /// Chapter/Page/Concept stable ID가 source manifest에도 등록되어 있는지 검사한다.
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
            var seenRevisitPageIDs = Set<LearningPageID>()
            for (index, reference) in (concept.revisitPages ?? []).enumerated() {
                let path = "concept[\(concept.id.rawValue)].revisitPages[\(index)]"
                if seenRevisitPageIDs.insert(reference.pageID).inserted == false {
                    issues.append(.init(
                        resource: resource,
                        fieldPath: path,
                        message: "duplicates a learning page in the same revisit section"
                    ))
                }
                requireIdentity(
                    .chapter,
                    id: reference.chapterID.rawValue,
                    keys: keys,
                    resource: resource,
                    issues: &issues
                )
                requireIdentity(
                    .page,
                    id: reference.pageID.rawValue,
                    keys: keys,
                    resource: resource,
                    issues: &issues
                )
                if reference.connection
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    issues.append(.init(
                        resource: resource,
                        fieldPath: "\(path).connection",
                        message: "must explain why the learning page is connected"
                    ))
                }
            }
        }
    }

    /// 한 Domain 객체에 필요한 `(kind, stableID)` manifest key가 빠졌으면 issue를 추가한다.
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

    // MARK: 공통 validation 도구

    /// 처음 본 ID의 field path를 기억하고, 재등장하면 최초 위치가 포함된 중복 issue를 만든다.
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

/// 여러 validation issue를 한 번에 호출자에게 전달하는 aggregate 오류.
struct ContentValidationError: Error, Sendable, CustomStringConvertible {
    let issues: [ContentValidationIssue]

    var description: String {
        issues.map(\.description).joined(separator: "\n")
    }
}

/// 콘텐츠 작성자가 수정할 수 있도록 resource·field path·이유를 보존하는 단일 문제.
struct ContentValidationIssue: Equatable, Sendable, CustomStringConvertible {
    let resource: String
    let fieldPath: String
    let message: String

    var description: String {
        "\(resource):\(fieldPath): \(message)"
    }
}

/// tagged payload 내부의 cross-resource 참조를 validator가 공통 방식으로 순회하게 하는 projection.
private extension LearningSectionContent {
    /// 이 payload가 참조하는 모든 공용 Concept ID. Concept를 쓰지 않는 case는 빈 배열이다.
    var referencedConceptIDs: [KnowledgeConceptID] {
        switch self {
        case let .definition(content):
            [content.conceptID]
        case let .knowledgeLink(content):
            content.links.map(\.conceptID)
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

    /// 개인 지식 승격/연결 payload가 근거로 삼는 Activity ID.
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

// MARK: - 다음 읽기: ConriculumTests/Content/ContentValidatorTests.swift
