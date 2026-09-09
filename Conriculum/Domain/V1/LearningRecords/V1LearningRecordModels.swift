import Foundation

// MARK: - 학습 과정에서 생성되는 사용자 기록

/// Chapter에서 현재 위치와 완료 상태를 stable page ID로 저장한다.
struct V1LearningProgress: Codable, Equatable, Sendable {
    let chapterID: ChapterID
    var currentPageID: LearningPageID
    var completedPageIDs: Set<LearningPageID>
    var updatedAt: Date
}

/// 사용자가 특정 Activity에 실제로 입력한 응답.
/// 활동 종류마다 다른 입력은 `fields`의 key-values 구조로 수용한다.
struct V1ActivityResponse: Codable, Equatable, Sendable {
    let id: ActivityResponseID
    let activityID: LearningActivityID
    let pageID: LearningPageID
    let fields: [V1ActivityResponseField]
    let recordedAt: Date
}

/// 하나의 응답 항목. 단일·복수 선택을 모두 표현하도록 값 배열을 사용한다.
struct V1ActivityResponseField: Codable, Equatable, Sendable {
    let key: String
    let values: [String]
}

/// 응답 내용과 별개로, 학습 과정에서 무엇이 관찰되었는지를 남기는 증거.
/// `V1ActivityResponse`가 “무엇을 했는가”라면 이 값은 “무엇이 확인되었는가”를 뜻한다.
struct V1LearningEvidence: Codable, Equatable, Sendable {
    let id: LearningEvidenceID
    let kind: V1LearningEvidenceKind
    let pageID: LearningPageID
    let activityID: LearningActivityID?
    let responseID: ActivityResponseID?
    let note: String?
    let recordedAt: Date
}

/// 단순 완료 여부보다 세분화된 학습 증거의 단계와 종류.
enum V1LearningEvidenceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case viewed
    case activityAttempt
    case assistedSuccess
    case independentSuccess
    case reasoningExplanation
    case conceptLink
}

// MARK: - 다음 읽기: ConriculumTests/Domain/KnowledgeAndLearningRecordTests.swift
