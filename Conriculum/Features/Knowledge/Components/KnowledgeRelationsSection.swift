import SwiftUI

/// 기본 관계와 개인 관계를 한 의미 단위로 보여 준다.
/// 편집·탐색 동작은 optional callback으로만 받아 어느 Feature에서도 재사용할 수 있다.
struct KnowledgeRelationsSection: View {
    let baseRelations: [KnowledgeRelation]
    let personalRelations: [PersonalKnowledgeRelation]
    let conceptIndex: KnowledgeConceptIndex
    let focusConceptID: KnowledgeConceptID?
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
        focusConceptID: KnowledgeConceptID? = nil,
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
        self.focusConceptID = focusConceptID
        self.canCreateRelation = canCreateRelation
        self.relationCreationUnavailableMessage = relationCreationUnavailableMessage
        self.onAddRelation = onAddRelation
        self.onEditPersonalRelation = onEditPersonalRelation
        self.onConceptSelected = onConceptSelected
        self.onCompareRequested = onCompareRequested
    }

    var body: some View {
        KnowledgeSection(
            title: "개념 사이의 관계",
            systemImage: "link",
            accent: .teal
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let focusConceptID {
                    directedBaseRelations(focusConceptID)
                } else if baseRelations.isEmpty {
                    Text("이 개념에 직접 연결된 기본 지식 관계가 없습니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    relationGroupTitle(
                        "기본 지식 연결",
                        systemImage: "books.vertical"
                    )
                    baseRelationRows
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
                    personalRelationRows
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

    @ViewBuilder
    private func directedBaseRelations(_ conceptID: KnowledgeConceptID) -> some View {
        let prerequisites = baseRelations.filter { $0.targetConceptID == conceptID }
        let next = baseRelations.filter { $0.sourceConceptID == conceptID }

        relationGroupTitle("선행 지식", systemImage: "arrow.left.circle")
        if prerequisites.isEmpty {
            Text("이 지식 경로의 출발점입니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            baseRelationRows(prerequisites)
        }

        relationGroupTitle("다음 연결", systemImage: "arrow.right.circle")
            .padding(.top, 4)
        if next.isEmpty {
            Text("이 지식 경로의 마지막 확인 지점입니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            baseRelationRows(next)
        }
    }

    private var baseRelationRows: some View {
        baseRelationRows(baseRelations)
    }

    private func baseRelationRows(_ relations: [KnowledgeRelation]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(relations.indices, id: \.self) { index in
                if index > relations.startIndex {
                    Divider()
                        .padding(.leading, 18)
                }

                KnowledgeBaseRelationRow(
                    relation: relations[index],
                    conceptIndex: conceptIndex,
                    onConceptSelected: onConceptSelected,
                    onCompareRequested: onCompareRequested
                )
                .padding(.vertical, 6)
            }
        }
    }

    private var personalRelationRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(personalRelations.indices, id: \.self) { index in
                if index > personalRelations.startIndex {
                    Divider()
                        .padding(.leading, 18)
                }

                KnowledgePersonalRelationRow(
                    relation: personalRelations[index],
                    conceptIndex: conceptIndex,
                    onConceptSelected: onConceptSelected,
                    onCompareRequested: onCompareRequested,
                    onEditRequested: onEditPersonalRelation
                )
                .padding(.vertical, 6)
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
