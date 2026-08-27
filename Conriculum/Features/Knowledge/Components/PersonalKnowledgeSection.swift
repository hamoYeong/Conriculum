import SwiftUI

/// 최신 개인 표현을 공용 지식과 구분해 읽기 전용으로 표시한다.
struct PersonalKnowledgeSection: View {
    let revision: PersonalConceptRevision?
    let emptyMessage: String

    init(
        revision: PersonalConceptRevision?,
        emptyMessage: String = "아직 확인해 저장한 나의 표현이 없습니다."
    ) {
        self.revision = revision
        self.emptyMessage = emptyMessage
    }

    var body: some View {
        KnowledgeSection(
            title: "나의 표현",
            systemImage: "person.crop.circle",
            accent: .purple
        ) {
            if let revision {
                VStack(alignment: .leading, spacing: 12) {
                    if let personalTitle = revision.personalTitle,
                       !personalTitle.isEmpty
                    {
                        KnowledgeLabeledText(
                            title: "나만의 이름",
                            text: personalTitle,
                            systemImage: "textformat"
                        )
                    }

                    KnowledgeLabeledText(
                        title: "나의 설명",
                        text: revision.explanation,
                        systemImage: "person.text.rectangle"
                    )

                    if !revision.examples.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("나의 예시", systemImage: "square.stack.3d.up")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(revision.examples, id: \.id) { example in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(example.text)
                                        .font(.callout)
                                    if let context = example.context,
                                       !context.isEmpty
                                    {
                                        Text(context)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            } else {
                Label(emptyMessage, systemImage: "person.crop.circle.badge.questionmark")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
            }
        }
    }
}
