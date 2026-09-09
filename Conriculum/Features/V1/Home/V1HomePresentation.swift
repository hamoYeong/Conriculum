struct V1HomeEvidencePresentation: Equatable, Sendable {
    let title: String
    let systemImage: String

    init(kind: V1LearningEvidenceKind) {
        switch kind {
        case .viewed:
            title = "열람"
            systemImage = "eye"

        case .activityAttempt:
            title = "활동 시도"
            systemImage = "cursorarrow.click"

        case .assistedSuccess:
            title = "도움으로 성공"
            systemImage = "person.2"

        case .independentSuccess:
            title = "독립 성공"
            systemImage = "checkmark.seal"

        case .reasoningExplanation:
            title = "판단 설명"
            systemImage = "text.bubble"

        case .conceptLink:
            title = "개념 연결"
            systemImage = "link"
        }
    }
}

extension V1HomeSnapshot.ChapterCard {
    var primaryActionTitle: String {
        resumePageID == nil
            ? "챕터 시작하기"
            : "챕터 이어하기"
    }

    var primaryActionAccessibilityHint: String {
        resumePageID == nil
            ? "챕터 개요에서 학습을 시작합니다."
            : "마지막으로 저장된 학습 페이지에서 계속합니다."
    }
}
