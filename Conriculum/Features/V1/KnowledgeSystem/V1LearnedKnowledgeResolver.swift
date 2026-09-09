import Foundation

/// Derives knowledge exposure and personal expression separately; neither implies mastery.
enum V1LearnedKnowledgeResolver {
    static func personalConceptIDs(page: V1LearningPage, responses: [V1ActivityResponse]) -> Set<KnowledgeConceptID> {
        guard page.kind == .lesson else { return [] }
        var result = Set<KnowledgeConceptID>()
        for response in latestResponses(page: page, responses: responses) {
            guard let activity = page.activities.first(where: { $0.id == response.activityID }),
                  let section = page.sections.first(where: { $0.id == activity.sectionID }) else { continue }
            func value(_ key: String) -> String {
                response.fields.first { $0.key == key }?.values.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            }
            let keys: [String]
            switch section.content {
            case .cardSorting, .matching, .choiceWithReason:
                keys = [V1LearningActivityFieldKey.reason]
            case .freeResponse:
                keys = [V1LearningActivityFieldKey.response]
            case .recallCheck:
                keys = response.fields.map(\.key).filter { $0.hasPrefix("recall.") }
            case .learningClosure:
                keys = [V1LearningActivityFieldKey.reflectionFinalExplanation,
                        V1LearningActivityFieldKey.reflectionChangedCriterion,
                        V1LearningActivityFieldKey.reflectionNextUse]
            case .semanticChunkReading:
                keys = [V1LearningActivityFieldKey.semanticChunkName, V1LearningActivityFieldKey.semanticChunkFlow,
                        V1LearningActivityFieldKey.semanticChunkBoundary, V1LearningActivityFieldKey.semanticChunkChange]
            case let .personalKnowledgePromotion(content):
                let expression = value(V1LearningActivityFieldKey.personalExpression)
                let target = KnowledgeConceptID(rawValue: value(V1LearningActivityFieldKey.personalizationTargetConceptID))
                if !expression.isEmpty, expression != content.editableDraft.trimmingCharacters(in: .whitespacesAndNewlines),
                   content.conceptIDs.contains(target) { result.insert(target) }
                continue
            case let .personalKnowledgeRelation(content):
                let source = KnowledgeConceptID(rawValue: value(V1LearningActivityFieldKey.relationSourceConceptID))
                let target = KnowledgeConceptID(rawValue: value(V1LearningActivityFieldKey.relationTargetConceptID))
                let statement = value(V1LearningActivityFieldKey.relationStatement)
                if content.sourceConceptIDs.contains(source), content.targetConceptIDs.contains(target), source != target,
                   !value(V1LearningActivityFieldKey.reason).isEmpty
                    || (!statement.isEmpty && statement != content.draftStatement.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    result.formUnion([source, target])
                }
                continue
            default:
                // Option IDs, code pieces, confidence selections and initial guesses are not personal explanations.
                continue
            }
            if keys.contains(where: { !value($0).isEmpty }) {
                result.formUnion(V1LearningExposure.directConceptIDs(page: page))
            }
        }
        return result
    }

    private static func latestResponses(page: V1LearningPage, responses: [V1ActivityResponse]) -> [V1ActivityResponse] {
        Array(responses.filter { $0.pageID == page.id }.reduce(into: [LearningActivityID: V1ActivityResponse]()) { result, response in
            if let current = result[response.activityID],
               (current.recordedAt, current.id.rawValue) > (response.recordedAt, response.id.rawValue) { return }
            result[response.activityID] = response
        }.values)
    }

    static func conceptIDs(
        page: V1LearningPage, responses: [V1ActivityResponse]
    ) -> Set<KnowledgeConceptID> {
        guard page.kind == .lesson else { return [] }
        let eligibleActivities = Set(page.activities.compactMap { activity in
            guard let section = page.sections.first(where: { $0.id == activity.sectionID }),
                  section.content.tag != .learningCompass else { return nil as LearningActivityID? }
            return activity.id
        })
        // Use the latest version of each response so clearing an answer does not revive old input.
        let latest = responses.filter { $0.pageID == page.id }.reduce(
            into: [LearningActivityID: V1ActivityResponse]()
        ) { result, response in
            if let existing = result[response.activityID],
               (existing.recordedAt, existing.id.rawValue) > (response.recordedAt, response.id.rawValue) { return }
            result[response.activityID] = response
        }
        guard latest.values.contains(where: { response in
            eligibleActivities.contains(response.activityID)
                && response.fields.contains { field in
                    field.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                }
        }) else { return [] }
        return V1LearningExposure.directConceptIDs(page: page)
    }
}
