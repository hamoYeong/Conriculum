import Foundation

enum HomePreviewFixtures {
    static let empty = HomeSnapshot(
        source: .empty,
        stage: .stageOne,
        chapter: HomeSnapshot.ChapterCard(
            chapterID: "chapter-02",
            title: "Chapter 2 · 정보를 값과 타입으로 표현하기",
            summary: "현실의 정보를 이름 붙은 Swift 값으로 선언하고 선택 근거를 설명합니다.",
            startPageID: "chapter-02-overview",
            resumePageID: nil,
            lastPage: nil,
            accessNote: "미리보기 상태 · 이 챕터에 직접 진입할 수 있습니다."
        ),
        lastActivity: nil,
        evidence: LearningEvidenceKind.allCases.map {
            HomeSnapshot.EvidenceSummary(kind: $0, count: 0, latestAt: nil)
        },
        knowledgeChanges: KnowledgeChangeCollection(
            confirmed: [],
            pending: []
        ),
        knowledgeChangesEmptyStateMessage:
            "아직 확인해 반영한 나의 표현이나 연결이 없습니다."
    )

    static let mock: HomeSnapshot = {
        let timestamp = Date(timeIntervalSince1970: 1_725_782_400)
        let counts: [LearningEvidenceKind: Int] = [
            .viewed: 3,
            .activityAttempt: 2,
            .assistedSuccess: 1,
            .independentSuccess: 1,
            .reasoningExplanation: 2,
            .conceptLink: 1,
        ]

        return HomeSnapshot(
            source: .previewFixture(
                disclosure: "미리보기용 학습 기록입니다. 실제 저장 기록이 아닙니다."
            ),
            stage: .stageOne,
            chapter: HomeSnapshot.ChapterCard(
                chapterID: "chapter-02",
                title: "Chapter 2 · 정보를 값과 타입으로 표현하기",
                summary: "현실의 정보를 이름 붙은 Swift 값으로 선언하고 선택 근거를 설명합니다.",
                startPageID: "chapter-02-overview",
                resumePageID: "chapter-02-page-03",
                lastPage: HomeSnapshot.PageSummary(
                    id: "chapter-02-page-03",
                    order: 3,
                    title: "정보에 맞는 타입 선택하기"
                ),
                accessNote: "미리보기 기록 · 이어하기 상태"
            ),
            lastActivity: HomeSnapshot.ActivitySummary(
                id: "activity-page03-choice",
                pageID: "chapter-02-page-03",
                pageTitle: "정보에 맞는 타입 선택하기",
                sectionTitle: "타입 선택 이유 제출",
                occurredAt: timestamp
            ),
            evidence: LearningEvidenceKind.allCases.map { kind in
                HomeSnapshot.EvidenceSummary(
                    kind: kind,
                    count: counts[kind, default: 0],
                    latestAt: counts[kind, default: 0] == 0 ? nil : timestamp
                )
            },
            knowledgeChanges: KnowledgeChangeCollection(
                confirmed: [
                    .revision(KnowledgeChangeCollection.Revision(
                        id: "preview-revision-type-selection",
                        conceptID: "concept-type-selection",
                        conceptTitle: "타입 선택",
                        personalTitle: "정보가 할 일을 먼저 보기",
                        explanation: "겉모양보다 의미와 이후 할 일을 기준으로 타입을 고릅니다.",
                        exampleCount: 1,
                        evidenceActivityID: "activity-page03-choice",
                        modifiedAt: timestamp
                    )),
                    .relation(KnowledgeChangeCollection.Relation(
                        id: "preview-relation-value-type-selection",
                        sourceConceptID: "concept-value",
                        sourceConceptTitle: "값",
                        targetConceptID: "concept-type-selection",
                        targetConceptTitle: "타입 선택",
                        statement: "값의 의미는 타입 선택의 기준으로 이어진다.",
                        reason: "이후 가능한 사용을 함께 판단하기 때문이다.",
                        evidenceActivityID: "activity-page03-choice",
                        modifiedAt: timestamp.addingTimeInterval(-60)
                    )),
                ],
                pending: [
                    KnowledgeChangeCollection.Pending(
                        id: "preview-candidate-value",
                        targetConceptID: "concept-value",
                        targetConceptTitle: "값",
                        connectedConceptTitles: ["값", "타입 선택"],
                        draft: "값의 의미와 이후 할 일을 함께 보고 타입을 고른다.",
                        evidenceActivityID: "activity-page03-choice",
                        createdAt: timestamp.addingTimeInterval(60)
                    ),
                ]
            ),
            knowledgeChangesEmptyStateMessage:
                "아직 확인해 반영한 나의 표현이나 연결이 없습니다."
        )
    }()
}
