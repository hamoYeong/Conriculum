import SwiftUI

/// 한 개념 상세 pane의 문맥과 제목을 설명하는 공통 header.
struct KnowledgeConceptHeader: View {
    let concept: KnowledgeConcept
    let contextTitle: String?
    let role: KnowledgeLinkRole?

    init(
        concept: KnowledgeConcept,
        contextTitle: String? = nil,
        role: KnowledgeLinkRole? = nil
    ) {
        self.concept = concept
        self.contextTitle = contextTitle
        self.role = role
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(concept.title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            if let contextTitle {
                Text("현재 문맥 · \(contextTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let role {
                Label(
                    "현재 페이지 역할 · \(KnowledgePresentation.compactTitle(for: role))",
                    systemImage: "scope"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
