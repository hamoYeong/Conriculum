import SwiftUI

/// Obsidian 지식 노트의 `다시 보기` 목록을 같은 순서와 설명으로 보여 준다.
struct KnowledgeRevisitSection: View {
    let references: [KnowledgeLearningReference]
    let onSelect: (KnowledgeLearningReference) -> Void

    var body: some View {
        KnowledgeSection(
            title: "다시 보기",
            systemImage: "arrow.counterclockwise",
            accent: .teal
        ) {
            if references.isEmpty {
                Text("아직 앱에 연결된 학습 페이지가 없습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(references) { reference in
                        Button {
                            onSelect(reference)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("Chapter \(reference.chapterOrder)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.teal)
                                    Text(reference.pageTitle)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 4)
                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(.secondary)
                                }
                                Text(reference.connection)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color.primary.opacity(0.035),
                                in: RoundedRectangle(cornerRadius: 9)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "Chapter \(reference.chapterOrder), \(reference.pageTitle) 다시 보기"
                        )
                        .accessibilityHint(reference.connection)
                    }
                }
            }
        }
    }
}
