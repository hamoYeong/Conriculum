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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Label("학습 문맥", systemImage: "sidebar.left")
                    .font(.title2.bold())
                    .accessibilityHeading(.h1)
                Text("Stage \(stage.order) · Chapter \(chapter.order)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(chapter.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            List {
                Section("이 챕터의 페이지") {
                    ForEach(chapter.pages.sorted(by: { $0.order < $1.order })) { page in
                        Button {
                            onPageSelected(page.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: pageSymbol(page.id))
                                    .foregroundStyle(
                                        page.id == currentPageID
                                            ? Color.accentColor
                                            : Color.secondary
                                    )
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(page.order). \(page.title)")
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

                Section("이 페이지의 지식 단서") {
                    if concepts.isEmpty {
                        Text("연결된 지식 단서가 없습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(concepts, id: \.id) { concept in
                            Button {
                                onConceptSelected(concept.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "lightbulb")
                                        .foregroundStyle(
                                            concept.id == selectedConceptID
                                                ? Color.accentColor
                                                : Color.secondary
                                        )
                                    Text(concept.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("오른쪽 인스펙터에서 판단 단서를 확인합니다.")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func pageSymbol(_ pageID: String) -> String {
        if pageID == currentPageID { return "play.circle.fill" }
        if completedPageIDs.contains(pageID) { return "checkmark.circle.fill" }
        return "circle"
    }
}

struct V2KnowledgeInspector: View {
    let concept: KnowledgeConcept
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("지식 단서", systemImage: "sidebar.right")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("인스펙터 닫기")
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(concept.title)
                            .font(.title2.bold())
                            .accessibilityHeading(.h1)
                        Text(concept.definition)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    inspectorSection(
                        title: "읽을 때 던질 질문",
                        systemImage: "questionmark.bubble",
                        values: [concept.essentialQuestion] + concept.judgmentQuestions
                    )
                    inspectorSection(
                        title: "다시 볼 학습 장면",
                        systemImage: "arrow.uturn.backward.circle",
                        values: concept.examples
                    )
                    inspectorSection(
                        title: "피할 오해",
                        systemImage: "exclamationmark.triangle",
                        values: concept.misconceptions
                    )
                }
                .padding(18)
            }
        }
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func inspectorSection(
        title: String,
        systemImage: String,
        values: [String]
    ) -> some View {
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Text("• \(value)")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
