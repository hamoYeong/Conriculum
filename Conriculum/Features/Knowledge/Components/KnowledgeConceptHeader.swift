import SwiftUI

/// 한 개념 상세 pane의 문맥과 제목을 설명하는 공통 header.
struct KnowledgeConceptHeader: View {
    let sectionTitle: String
    let sectionSystemImage: String
    let concept: KnowledgeConcept
    let contextTitle: String?
    let role: KnowledgeLinkRole?

    init(
        sectionTitle: String = "개념 상세",
        sectionSystemImage: String = "sidebar.trailing",
        concept: KnowledgeConcept,
        contextTitle: String? = nil,
        role: KnowledgeLinkRole? = nil
    ) {
        self.sectionTitle = sectionTitle
        self.sectionSystemImage = sectionSystemImage
        self.concept = concept
        self.contextTitle = contextTitle
        self.role = role
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(sectionTitle, systemImage: sectionSystemImage)
                .font(.title2.weight(.semibold))
                .accessibilityHeading(.h1)

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
