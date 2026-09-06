import SwiftUI

struct V2LearningSidebar: View {
    let stage: V2Stage
    let chapter: V2Chapter
    let currentPageID: String
    let completedPageIDs: Set<String>
    let concepts: [KnowledgeConcept]
    let selectedConceptID: KnowledgeConceptID?
    let onPageSelected: (String) -> Void
    let onConceptSelected: (KnowledgeConceptID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("학습 문맥", systemImage: "scope")
                    .font(.headline)
                    .accessibilityHeading(.h1)

                if let current = chapter.pages.first(where: { $0.id == currentPageID }) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("지금의 질문", systemImage: "questionmark.bubble.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                        Text(current.goal)
                            .font(.callout.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.18)) }
                }

                if let core = concepts.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("지금 쓰는 기준", systemImage: "target")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                        conceptButton(core, isCore: true)
                    }
                }

                if concepts.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("함께 쓰는 개념", systemImage: "link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.teal)
                        ForEach(concepts.dropFirst(), id: \.id) { concept in
                            conceptButton(concept, isCore: false)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("이 챕터의 페이지", systemImage: "list.bullet.rectangle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(chapter.pages.sorted(by: { $0.order < $1.order })) { page in
                        Button {
                            onPageSelected(page.id)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: pageSymbol(page.id))
                                    .foregroundStyle(
                                        page.id == currentPageID
                                            ? Color.accentColor
                                            : Color.secondary
                                    )
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(page.title)
                                        .lineLimit(2)
                                    if page.id == currentPageID {
                                        Text("현재 페이지")
                                            .font(.caption2)
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(page.id == currentPageID ? "현재 페이지" : "")
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityLabel("현재 학습의 지식 문맥")
    }

    private func conceptButton(_ concept: KnowledgeConcept, isCore: Bool) -> some View {
        Button {
            onConceptSelected(concept.id)
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: isCore ? "target" : "circle.fill")
                    .font(isCore ? .caption : .system(size: 6))
                    .foregroundStyle(isCore ? .blue : .teal)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(concept.title).font(.callout.weight(.semibold))
                    if isCore {
                        Text(concept.definition)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(isCore ? 12 : 5)
            .contentShape(Rectangle())
            .background(
                isCore ? Color(nsColor: .controlBackgroundColor) : .clear,
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay {
                if isCore {
                    RoundedRectangle(cornerRadius: 11).stroke(Color.blue.opacity(0.18))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(concept.id == selectedConceptID ? .isSelected : [])
        .accessibilityHint("개념의 기본 지식과 다음 연결을 봅니다.")
    }

    private func pageSymbol(_ pageID: String) -> String {
        if pageID == currentPageID { return "play.circle.fill" }
        if completedPageIDs.contains(pageID) { return "checkmark.circle.fill" }
        return "circle"
    }
}

struct V2KnowledgeInspector: View {
    let concept: KnowledgeConcept
    let relations: [KnowledgeRelation]
    let concepts: [KnowledgeConcept]
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    KnowledgeConceptHeader(concept: concept)
                    Spacer(minLength: 8)
                    Button(action: onDismiss) { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .help("이 상세 닫기")
                        .accessibilityLabel("\(concept.title) 상세 닫기")
                }

                BaseKnowledgeSection(concept: concept, detailLevel: .complete)

                KnowledgeRelationsSection(
                    baseRelations: relations.filter {
                        $0.sourceConceptID == concept.id || $0.targetConceptID == concept.id
                    },
                    personalRelations: [],
                    conceptIndex: KnowledgeConceptIndex(concepts: concepts),
                    focusConceptID: concept.id
                )
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
