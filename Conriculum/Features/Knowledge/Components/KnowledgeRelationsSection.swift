import SwiftUI

/// 기본 관계와 개인 관계를 한 의미 단위로 보여 준다.
/// 편집·탐색 동작은 optional callback으로만 받아 어느 Feature에서도 재사용할 수 있다.
struct KnowledgeRelationsSection: View {
    let baseRelations: [KnowledgeRelation]
    let personalRelations: [PersonalKnowledgeRelation]
    let conceptIndex: KnowledgeConceptIndex
    let canCreateRelation: Bool
    let relationCreationUnavailableMessage: String?
    var onAddRelation: (() -> Void)?
    var onEditPersonalRelation: ((PersonalKnowledgeRelationID) -> Void)?
    var onConceptSelected: ((KnowledgeConceptID) -> Void)?
    var onCompareRequested: ((KnowledgeConceptID, KnowledgeConceptID) -> Void)?

    init(
        baseRelations: [KnowledgeRelation],
        personalRelations: [PersonalKnowledgeRelation],
        conceptIndex: KnowledgeConceptIndex,
        canCreateRelation: Bool = false,
        relationCreationUnavailableMessage: String? = nil,
        onAddRelation: (() -> Void)? = nil,
        onEditPersonalRelation: ((PersonalKnowledgeRelationID) -> Void)? = nil,
        onConceptSelected: ((KnowledgeConceptID) -> Void)? = nil,
        onCompareRequested: ((KnowledgeConceptID, KnowledgeConceptID) -> Void)? = nil
    ) {
        self.baseRelations = baseRelations
        self.personalRelations = personalRelations
        self.conceptIndex = conceptIndex
        self.canCreateRelation = canCreateRelation
        self.relationCreationUnavailableMessage = relationCreationUnavailableMessage
        self.onAddRelation = onAddRelation
        self.onEditPersonalRelation = onEditPersonalRelation
        self.onConceptSelected = onConceptSelected
        self.onCompareRequested = onCompareRequested
    }

    var body: some View {
        KnowledgeSectionChrome(
            title: "개념 사이의 관계",
            systemImage: "link",
            accent: .teal
        ) {
            VStack(alignment: .leading, spacing: 14) {
                relationGroupTitle(
                    "기본 지식 연결",
                    systemImage: "books.vertical"
                )

                if baseRelations.isEmpty {
                    Text("이 개념에 직접 연결된 기본 지식 관계가 없습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(baseRelations, id: \.id) { relation in
                        KnowledgeBaseRelationRow(
                            relation: relation,
                            conceptIndex: conceptIndex,
                            onConceptSelected: onConceptSelected,
                            onCompareRequested: onCompareRequested
                        )
                    }
                }

                Divider()

                HStack {
                    relationGroupTitle(
                        "나의 지식 연결",
                        systemImage: "person.2"
                    )
                    Spacer()

                    if let onAddRelation {
                        Button {
                            onAddRelation()
                        } label: {
                            Label("관계 추가", systemImage: "plus")
                        }
                        .controlSize(.small)
                        .disabled(!canCreateRelation)
                        .accessibilityHint(
                            "현재 문맥이 허용한 두 개념으로 개인 관계 초안을 만듭니다."
                        )
                    }
                }

                if personalRelations.isEmpty {
                    Text("아직 확인해 저장한 개인 관계가 없습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(personalRelations, id: \.id) { relation in
                        KnowledgePersonalRelationRow(
                            relation: relation,
                            conceptIndex: conceptIndex,
                            onConceptSelected: onConceptSelected,
                            onCompareRequested: onCompareRequested,
                            onEditRequested: onEditPersonalRelation
                        )
                    }
                }

                if let relationCreationUnavailableMessage {
                    Label(
                        relationCreationUnavailableMessage,
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func relationGroupTitle(
        _ title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.callout.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
    }
}
