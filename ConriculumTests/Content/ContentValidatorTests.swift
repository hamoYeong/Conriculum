import Foundation
import Testing

@testable import Conriculum

struct ContentValidatorTests {
    @Test
    func bundledChapterTwoContentPassesValidation() throws {
        let content = try loadValidContent()

        try ContentValidator().validate(
            chapter: content.chapter,
            catalog: content.catalog,
            identityManifest: content.identityManifest
        )
    }

    @Test
    func duplicatePageIDAndMissingOrderReportExactFields() throws {
        let content = try loadValidContent()
        var pages = content.chapter.pages
        pages[1] = copyPage(
            pages[1],
            id: pages[0].id,
            order: nil
        )
        let brokenChapter = copyChapter(content.chapter, pages: pages)

        let error = validationError(
            chapter: brokenChapter,
            catalog: content.catalog,
            identityManifest: content.identityManifest
        )

        #expect(error.issues.contains {
            $0.resource.hasSuffix("chapter-02.json")
                && $0.fieldPath == "pages[1].id"
                && $0.message.contains("duplicate page ID")
        })
        #expect(error.issues.contains {
            $0.fieldPath == "pages.order"
                && $0.message.contains("1 through 8")
        })
    }

    @Test
    func brokenKnowledgeAndActivityLinksReportTheirPayloadFields() throws {
        let content = try loadValidContent()
        var pages = content.chapter.pages

        var firstPageSections = pages[0].sections
        let promotionIndex = try #require(firstPageSections.firstIndex {
            $0.content.tag == .personalKnowledgePromotion
        })
        firstPageSections[promotionIndex] = copySection(
            firstPageSections[promotionIndex],
            content: brokenPromotionContent(firstPageSections[promotionIndex].content)
        )
        pages[0] = copyPage(
            pages[0],
            sections: firstPageSections,
            knowledgeLinks: pages[0].knowledgeLinks + [
                LearningKnowledgeLink(
                    conceptID: "concept-does-not-exist",
                    role: .supporting,
                    usage: "깨진 fixture",
                    displayTiming: nil
                )
            ]
        )

        var seventhPageSections = pages[6].sections
        let relationIndex = try #require(seventhPageSections.firstIndex {
            $0.content.tag == .personalKnowledgeRelation
        })
        seventhPageSections[relationIndex] = copySection(
            seventhPageSections[relationIndex],
            content: brokenRelationContent(seventhPageSections[relationIndex].content)
        )
        pages[6] = copyPage(pages[6], sections: seventhPageSections)

        let error = validationError(
            chapter: copyChapter(content.chapter, pages: pages),
            catalog: content.catalog,
            identityManifest: content.identityManifest
        )

        #expect(error.issues.contains {
            $0.fieldPath == "pages[0].knowledgeLinks[3].conceptID"
                && $0.message.contains("does not resolve")
        })
        #expect(error.issues.contains {
            $0.fieldPath.contains("pages[0].sections")
                && $0.fieldPath.hasSuffix("evidenceActivityIDs")
                && $0.message.contains("activity-missing-promotion")
        })
        #expect(error.issues.contains {
            $0.fieldPath.contains("pages[6].sections")
                && $0.fieldPath.hasSuffix("evidenceActivityIDs")
                && $0.message.contains("activity-missing-relation")
        })
    }

    @Test
    func brokenCatalogRelationAndMissingIdentityAreRejected() throws {
        let content = try loadValidContent()
        var relations = content.catalog.relations
        let firstRelation = try #require(relations.first)
        relations[0] = KnowledgeRelation(
            id: firstRelation.id,
            sourceConceptID: firstRelation.sourceConceptID,
            targetConceptID: "concept-does-not-exist",
            kind: firstRelation.kind,
            summary: firstRelation.summary
        )
        let brokenCatalog = KnowledgeCatalog(
            schemaVersion: content.catalog.schemaVersion,
            id: content.catalog.id,
            title: content.catalog.title,
            concepts: content.catalog.concepts,
            relations: relations
        )
        let brokenManifest = ContentIdentityManifest(
            schemaVersion: content.identityManifest.schemaVersion,
            identities: content.identityManifest.identities.filter {
                $0.stableID != "chapter-02-page-08"
            }
        )

        let error = validationError(
            chapter: content.chapter,
            catalog: brokenCatalog,
            identityManifest: brokenManifest
        )

        #expect(error.issues.contains {
            $0.resource.hasSuffix("values-and-types.json")
                && $0.fieldPath == "relations[0].targetConceptID"
        })
        #expect(error.issues.contains {
            $0.resource.hasSuffix("content-identity.json")
                && $0.message.contains("chapter-02-page-08")
        })
    }

    private func loadValidContent() throws -> ValidContent {
        let decoder = ContentResourceDecoder()
        return try ValidContent(
            chapter: decoder.decode(Chapter.self, from: .chapter02),
            catalog: decoder.decode(KnowledgeCatalog.self, from: .valuesAndTypes),
            identityManifest: decoder.decode(ContentIdentityManifest.self, from: .contentIdentity)
        )
    }

    private func validationError(
        chapter: Chapter,
        catalog: KnowledgeCatalog,
        identityManifest: ContentIdentityManifest
    ) -> ContentValidationError {
        do {
            try ContentValidator().validate(
                chapter: chapter,
                catalog: catalog,
                identityManifest: identityManifest
            )
            Issue.record("깨진 fixture가 validation을 통과했다.")
            return ContentValidationError(issues: [])
        } catch let error as ContentValidationError {
            return error
        } catch {
            Issue.record("예상하지 못한 오류: \(error)")
            return ContentValidationError(issues: [])
        }
    }

    private func copyChapter(_ chapter: Chapter, pages: [LearningPage]) -> Chapter {
        Chapter(
            id: chapter.id,
            stageID: chapter.stageID,
            order: chapter.order,
            title: chapter.title,
            summary: chapter.summary,
            overview: chapter.overview,
            pages: pages
        )
    }

    private func copyPage(
        _ page: LearningPage,
        id: LearningPageID,
        order: Int?
    ) -> LearningPage {
        LearningPage(
            id: id,
            kind: page.kind,
            order: order,
            title: page.title,
            goal: page.goal,
            sections: page.sections,
            activities: page.activities,
            knowledgeLinks: page.knowledgeLinks,
            knowledgeContext: page.knowledgeContext,
            navigation: page.navigation
        )
    }

    private func copyPage(
        _ page: LearningPage,
        sections: [LearningSection],
        knowledgeLinks: [LearningKnowledgeLink]? = nil
    ) -> LearningPage {
        LearningPage(
            id: page.id,
            kind: page.kind,
            order: page.order,
            title: page.title,
            goal: page.goal,
            sections: sections,
            activities: page.activities,
            knowledgeLinks: knowledgeLinks ?? page.knowledgeLinks,
            knowledgeContext: page.knowledgeContext,
            navigation: page.navigation
        )
    }

    private func copySection(
        _ section: LearningSection,
        content: LearningSectionContent
    ) -> LearningSection {
        LearningSection(
            id: section.id,
            order: section.order,
            title: section.title,
            activityID: section.activityID,
            content: content
        )
    }

    private func brokenPromotionContent(
        _ content: LearningSectionContent
    ) -> LearningSectionContent {
        guard case let .personalKnowledgePromotion(value) = content else {
            Issue.record("개인 지식 반영 section을 찾지 못했다.")
            return content
        }

        return .personalKnowledgePromotion(
            PersonalKnowledgePromotionContent(
                evidenceActivityIDs: ["activity-missing-promotion"],
                conceptIDs: value.conceptIDs,
                candidateKind: value.candidateKind,
                editableDraft: value.editableDraft,
                confirmationQuestion: value.confirmationQuestion,
                savedFields: value.savedFields,
                cancellationResult: value.cancellationResult
            )
        )
    }

    private func brokenRelationContent(
        _ content: LearningSectionContent
    ) -> LearningSectionContent {
        guard case let .personalKnowledgeRelation(value) = content else {
            Issue.record("나의 연결 만들기 section을 찾지 못했다.")
            return content
        }

        return .personalKnowledgeRelation(
            PersonalKnowledgeRelationSectionContent(
                sourceConceptIDs: value.sourceConceptIDs,
                targetConceptIDs: value.targetConceptIDs,
                draftStatement: value.draftStatement,
                reasonPrompt: value.reasonPrompt,
                evidenceActivityIDs: ["activity-missing-relation"],
                confirmationQuestion: value.confirmationQuestion
            )
        )
    }
}

private struct ValidContent {
    let chapter: Chapter
    let catalog: KnowledgeCatalog
    let identityManifest: ContentIdentityManifest
}
