// MARK: - 1. 모든 Domain이 공유하는 식별자 규칙

/// ID 종류를 구분하기 위한 marker protocol.
/// 기능을 제공하기보다, `Tag`가 서로 다른 ID namespace를 만들게 한다.
protocol StableIDTag: Sendable {}

/// 문자열 하나를 저장하되 `Tag`로 ID 종류를 구분하는 type-safe 식별자.
/// 예를 들어 `LearningPageID`와 `ChapterID`는 같은 문자열을 담아도 서로 다른 Swift 타입이다.
struct StableID<Tag: StableIDTag>: RawRepresentable, Codable, Hashable, Sendable {
    /// JSON과 외부 리소스에서 사용하는 안정적인 원문 식별자.
    let rawValue: String

    /// 명시적인 문자열을 해당 `Tag`의 식별자로 감싼다.
    init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// JSON의 단일 문자열을 객체 wrapper 없이 `StableID`로 복원한다.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    /// `StableID`를 `{ "rawValue": ... }`가 아닌 JSON 단일 문자열로 기록한다.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// 테스트와 fixture에서 `let id: LearningPageID = "chapter-02-page-01"`처럼 선언하게 한다.
extension StableID: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

/// 로그와 validation 오류에는 wrapper 대신 원문 식별자를 표시한다.
extension StableID: CustomStringConvertible {
    var description: String { rawValue }
}

// 빈 Tag 각각이 별도의 ID namespace를 만든다.
enum LearningPathIDTag: StableIDTag {}
enum LocalProfileIDTag: StableIDTag {}
enum StageIDTag: StableIDTag {}
enum ChapterIDTag: StableIDTag {}
enum LearningPageIDTag: StableIDTag {}
enum LearningSectionIDTag: StableIDTag {}
enum LearningActivityIDTag: StableIDTag {}
enum KnowledgeCollectionIDTag: StableIDTag {}
enum KnowledgeConceptIDTag: StableIDTag {}
enum KnowledgeRelationIDTag: StableIDTag {}
enum PersonalConceptRevisionIDTag: StableIDTag {}
enum PersonalKnowledgeRelationIDTag: StableIDTag {}
enum PersonalExampleIDTag: StableIDTag {}
enum KnowledgePersonalizationCandidateIDTag: StableIDTag {}
enum ActivityResponseIDTag: StableIDTag {}
enum LearningEvidenceIDTag: StableIDTag {}

// Domain에서는 generic 표현을 숨기고 의미가 드러나는 이름으로 사용한다.
typealias LearningPathID = StableID<LearningPathIDTag>
typealias LocalProfileID = StableID<LocalProfileIDTag>
typealias StageID = StableID<StageIDTag>
typealias ChapterID = StableID<ChapterIDTag>
typealias LearningPageID = StableID<LearningPageIDTag>
typealias LearningSectionID = StableID<LearningSectionIDTag>
typealias LearningActivityID = StableID<LearningActivityIDTag>
typealias KnowledgeCollectionID = StableID<KnowledgeCollectionIDTag>
typealias KnowledgeConceptID = StableID<KnowledgeConceptIDTag>
typealias KnowledgeRelationID = StableID<KnowledgeRelationIDTag>
typealias PersonalConceptRevisionID = StableID<PersonalConceptRevisionIDTag>
typealias PersonalKnowledgeRelationID = StableID<PersonalKnowledgeRelationIDTag>
typealias PersonalExampleID = StableID<PersonalExampleIDTag>
typealias KnowledgePersonalizationCandidateID = StableID<KnowledgePersonalizationCandidateIDTag>
typealias ActivityResponseID = StableID<ActivityResponseIDTag>
typealias LearningEvidenceID = StableID<LearningEvidenceIDTag>

// MARK: - 다음 읽기: Domain/Curriculum/CurriculumModels.swift
