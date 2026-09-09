import Foundation

struct V1HomeSnapshotComposer {
    func compose(
        chapter: V1Chapter,
        catalog: KnowledgeCatalog,
        progress: V1LearningProgress?,
        responses: [V1ActivityResponse],
        evidence: [V1LearningEvidence],
        revisions: [PersonalConceptRevision],
        relations: [PersonalKnowledgeRelation] = [],
        pendingPersonalizationReviews: [
            V1KnowledgePersonalizationReview
        ] = [],
        placeholder: V1HomeSnapshot? = nil,
        availableChapters: [V1Chapter]? = nil,
        progressByChapter: [ChapterID: V1LearningProgress] = [:]
    ) -> V1HomeSnapshot {
        let hasStoredRecords = progress != nil
            || responses.isEmpty == false
            || evidence.isEmpty == false
            || revisions.isEmpty == false
            || relations.isEmpty == false
            || pendingPersonalizationReviews.isEmpty == false

        if hasStoredRecords == false, let placeholder {
            return placeholder
        }

        let resumedPage = progress.flatMap { progress in
            chapter.page(id: progress.currentPageID)
        }
        return V1HomeSnapshot(
            source: hasStoredRecords ? .recorded : .empty,
            stage: .stageOne,
            chapter: V1HomeSnapshot.ChapterCard(
                chapterID: chapter.id,
                title: "Chapter \(chapter.order) · \(chapter.title)",
                summary: chapter.summary,
                startPageID: chapter.overview.id,
                resumePageID: resumedPage?.id,
                lastPage: resumedPage.map {
                    V1HomeSnapshot.PageSummary(
                        id: $0.id,
                        order: $0.order,
                        title: $0.title
                    )
                },
                accessNote: nil
            ),
            lastActivity: lastActivity(
                chapter: chapter,
                responses: responses,
                evidence: evidence
            ),
            evidence: V1LearningEvidenceKind.allCases.map { kind in
                let matchingEvidence = evidence.filter { $0.kind == kind }
                return V1HomeSnapshot.EvidenceSummary(
                    kind: kind,
                    count: matchingEvidence.count,
                    latestAt: matchingEvidence.map(\.recordedAt).max()
                )
            },
            knowledgeChanges: V1KnowledgeChangeCollectionComposer().compose(
                concepts: catalog.concepts,
                revisions: revisions,
                relations: relations,
                pendingReviews: pendingPersonalizationReviews
            ),
            knowledgeChangesEmptyStateMessage: chapter.overview
                .knowledgeContext.emptyStateMessage,
            availableChapters: (availableChapters ?? [chapter]).sorted {
                ($0.order, $0.id.rawValue) < ($1.order, $1.id.rawValue)
            }.map { item in
                let record = progressByChapter[item.id] ?? (item.id == chapter.id ? progress : nil)
                let page = record.flatMap { item.page(id: $0.currentPageID) }
                return V1HomeSnapshot.ChapterCard(
                    chapterID: item.id,
                    title: "Chapter \(item.order) · \(item.title)",
                    summary: item.summary, startPageID: item.overview.id,
                    resumePageID: page?.id,
                    lastPage: page.map { .init(id: $0.id, order: $0.order, title: $0.title) },
                    accessNote: nil
                )
            }
        )
    }

    private func lastActivity(
        chapter: V1Chapter,
        responses: [V1ActivityResponse],
        evidence: [V1LearningEvidence]
    ) -> V1HomeSnapshot.ActivitySummary? {
        let responseCandidates = responses.compactMap { response in
            activityCandidate(
                chapter: chapter,
                pageID: response.pageID,
                activityID: response.activityID,
                occurredAt: response.recordedAt,
                stableTieBreaker: response.id.rawValue
            )
        }
        let evidenceCandidates = evidence.compactMap { evidence in
            evidence.activityID.flatMap { activityID in
                activityCandidate(
                    chapter: chapter,
                    pageID: evidence.pageID,
                    activityID: activityID,
                    occurredAt: evidence.recordedAt,
                    stableTieBreaker: evidence.id.rawValue
                )
            }
        }

        return (responseCandidates + evidenceCandidates).max {
            if $0.summary.occurredAt != $1.summary.occurredAt {
                return $0.summary.occurredAt < $1.summary.occurredAt
            }
            return $0.stableTieBreaker < $1.stableTieBreaker
        }?.summary
    }

    private func activityCandidate(
        chapter: V1Chapter,
        pageID: LearningPageID,
        activityID: LearningActivityID,
        occurredAt: Date,
        stableTieBreaker: String
    ) -> ActivityCandidate? {
        guard let page = chapter.page(id: pageID),
              let activity = page.activities.first(where: { $0.id == activityID })
        else { return nil }
        let section = page.sections.first { $0.id == activity.sectionID }

        return ActivityCandidate(
            summary: V1HomeSnapshot.ActivitySummary(
                id: activityID,
                pageID: pageID,
                pageTitle: page.title,
                sectionTitle: section?.title,
                occurredAt: occurredAt
            ),
            stableTieBreaker: stableTieBreaker
        )
    }
}

private struct ActivityCandidate {
    let summary: V1HomeSnapshot.ActivitySummary
    let stableTieBreaker: String
}
