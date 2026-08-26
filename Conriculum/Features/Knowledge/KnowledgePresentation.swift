import Foundation

/// 지식 화면에서 stable ID를 사용자에게 읽을 수 있는 개념명으로 바꾼다.
///
/// Catalog 순서나 특정 Feature 상태에 기대지 않으므로 학습 Inspector와
/// 전체 지식 탐색기가 같은 fallback 규칙을 사용할 수 있다.
struct KnowledgeConceptIndex: Equatable, Sendable {
    private let titlesByID: [KnowledgeConceptID: String]

    init(concepts: [KnowledgeConcept]) {
        titlesByID = Dictionary(
            concepts.map { ($0.id, $0.title) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    init(titlesByID: [KnowledgeConceptID: String]) {
        self.titlesByID = titlesByID
    }

    func title(
        for conceptID: KnowledgeConceptID,
        fallback: String = "알 수 없는 개념"
    ) -> String {
        titlesByID[conceptID] ?? fallback
    }

    func endpoints(
        sourceConceptID: KnowledgeConceptID,
        targetConceptID: KnowledgeConceptID
    ) -> String {
        "\(title(for: sourceConceptID)) → \(title(for: targetConceptID))"
    }
}

/// Domain enum을 화면 문구로 투영하는 단일 진입점.
/// Domain 모델에 표시 문구를 넣지 않아 콘텐츠와 UI 책임을 분리한다.
enum KnowledgePresentation {
    static func compactTitle(for role: KnowledgeLinkRole) -> String {
        switch role {
        case .primary: "핵심"
        case .supporting: "보조"
        case .prerequisite: "선행"
        case .enrichment: "확장·심화"
        }
    }

    static func title(for kind: KnowledgeRelationKind) -> String {
        switch kind {
        case .prerequisite: "선행 관계"
        case .related: "관련 관계"
        case .contrastsWith: "대조 관계"
        case .refines: "구체화 관계"
        case .appliesTo: "적용 관계"
        case .leadsTo: "다음으로 이어지는 관계"
        }
    }

    static func systemImage(for kind: KnowledgeRelationKind) -> String {
        switch kind {
        case .prerequisite: "arrow.left"
        case .related: "link"
        case .contrastsWith: "arrow.left.arrow.right"
        case .refines: "arrow.down.right"
        case .appliesTo: "scope"
        case .leadsTo: "arrow.right"
        }
    }
}
