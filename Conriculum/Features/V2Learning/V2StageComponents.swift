import SwiftUI

/// Stage 1은 알아보기·대조·보스 전이를 게임 라운드로 보여 준다.
struct V2StageOneGameComponent: View {
    let page: V2LearningPage
    let responses: [String: V2GameResponse]
    let drafts: [String: V2GameDraft]
    let onOptionTapped: (String, String) -> Void
    let onMatchChanged: (String, String, String) -> Void
    let onSubmit: (String) -> Void

    init(
        page: V2LearningPage,
        responses: [String: V2GameResponse] = [:],
        drafts: [String: V2GameDraft] = [:],
        onOptionTapped: @escaping (String, String) -> Void = { _, _ in },
        onMatchChanged: @escaping (String, String, String) -> Void = { _, _, _ in },
        onSubmit: @escaping (String) -> Void = { _ in }
    ) {
        self.page = page
        self.responses = responses
        self.drafts = drafts
        self.onOptionTapped = onOptionTapped
        self.onMatchChanged = onMatchChanged
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(page.blocks.sorted(by: { $0.order < $1.order })) { block in
                V2GameBlock(
                    block: block,
                    responses: responses,
                    drafts: drafts,
                    onOptionTapped: onOptionTapped,
                    onMatchChanged: onMatchChanged,
                    onSubmit: onSubmit
                )
            }
        }
    }
}

private struct V2GameBlock: View {
    let block: V2ContentBlock
    let responses: [String: V2GameResponse]
    let drafts: [String: V2GameDraft]
    let onOptionTapped: (String, String) -> Void
    let onMatchChanged: (String, String, String) -> Void
    let onSubmit: (String) -> Void

    private var accent: Color {
        switch block.kind {
        case .mission: .blue
        case .boss: .purple
        case .unlock: .green
        case .game: .orange
        default: .indigo
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(block.title, systemImage: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .accessibilityHeading(.h2)

            if let wordSystem = block.wordSystem {
                V2WordSystemComponent(content: wordSystem)
            } else if let knowledgeUnlock = block.knowledgeUnlock {
                V2KnowledgeUnlockComponent(content: knowledgeUnlock)
            } else if block.activities.isEmpty {
                V2MarkdownContent(markdown: block.markdown)
            } else {
                ForEach(block.activities) { activity in
                    V2GameActivityView(
                        activity: activity,
                        response: responses[activity.id],
                        draft: drafts[activity.id],
                        onOptionTapped: { onOptionTapped(activity.id, $0) },
                        onMatchChanged: { pairID, rightPairID in
                            onMatchChanged(activity.id, pairID, rightPairID)
                        },
                        onSubmit: { onSubmit(activity.id) }
                    )
                    if activity.id != block.activities.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var symbol: String {
        switch block.kind {
        case .mission: "flag.checkered"
        case .wordSystem: "rectangle.3.group"
        case .scene: "sparkles.rectangle.stack"
        case .game: "gamecontroller"
        case .boss: "crown"
        case .unlock: "lock.open"
        default: "lightbulb"
        }
    }
}

struct V2WordSystemComponent: View {
    let content: V2WordSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(content.entries) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(markdown: entry.term)
                            .font(.headline)
                        Text(entry.parentSystem)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                    Text(markdown: entry.role)
                        .fixedSize(horizontal: false, vertical: true)
                    Label {
                        Text(markdown: entry.firstThought)
                    } icon: {
                        Image(systemName: "eye")
                    }
                    .font(.callout)
                    .foregroundStyle(.indigo)
                }
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)

                if entry.id != content.entries.last?.id {
                    Divider()
                }
            }
        }
    }
}

struct V2KnowledgeUnlockComponent: View {
    let content: V2KnowledgeUnlock

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(content.cards) { card in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.open.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(markdown: card.title)
                                .font(.headline)
                            Text(markdown: card.summary)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(Color.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Label("해금 기준", systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.semibold))
                Text(markdown: content.completionCriteria)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DisclosureGroup {
                Text(markdown: content.beginnerHint)
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)
            } label: {
                Label("막히면", systemImage: "lifepreserver")
            }

            DisclosureGroup {
                Text(markdown: content.advancedTip)
                    .padding(.top, 6)
                    .fixedSize(horizontal: false, vertical: true)
            } label: {
                Label("이미 안다면", systemImage: "sparkles")
            }
        }
    }
}

private extension Text {
    init(markdown: String) {
        self.init((try? AttributedString(markdown: markdown)) ?? AttributedString(markdown))
    }
}

private struct V2GameActivityView: View {
    let activity: V2GameActivity
    let response: V2GameResponse?
    let draft: V2GameDraft?
    let onOptionTapped: (String) -> Void
    let onMatchChanged: (String, String) -> Void
    let onSubmit: () -> Void
    @State private var selectedRightPairID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            V2MarkdownContent(markdown: activity.promptMarkdown)

            if activity.kind == .matching {
                matchingActivity
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 210), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(activity.options) { option in
                        optionCard(option)
                    }
                }

                if activity.kind == .multipleChoice {
                    HStack {
                        Text("여러 카드를 고를 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("선택 완료", action: onSubmit)
                            .buttonStyle(.borderedProminent)
                            .disabled(selectedOptionIDs.isEmpty)
                    }
                }
            }

            if let response, draft == nil {
                feedback(response)
            } else {
                Label(instruction, systemImage: "hand.tap")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func optionCard(_ option: V2GameActivity.Option) -> some View {
        let isSelected = selectedOptionIDs.contains(option.id)
        let showsJudgment = response != nil && draft == nil
        let selectedIsCorrect = showsJudgment && isSelected && activity.correctOptionIDs.contains(option.id)
        let selectedIsIncorrect = showsJudgment && isSelected && !activity.correctOptionIDs.contains(option.id)

        return Button {
            onOptionTapped(option.id)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: cardSymbol(
                    selectedIsCorrect: selectedIsCorrect,
                    selectedIsIncorrect: selectedIsIncorrect
                ))
                .foregroundStyle(cardAccent(
                    selectedIsCorrect: selectedIsCorrect,
                    selectedIsIncorrect: selectedIsIncorrect
                ))
                .accessibilityHidden(true)
                Text(attributed(option.title))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            cardAccent(
                selectedIsCorrect: selectedIsCorrect,
                selectedIsIncorrect: selectedIsIncorrect
            ).opacity(isSelected ? 0.13 : 0.04),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    cardAccent(
                        selectedIsCorrect: selectedIsCorrect,
                        selectedIsIncorrect: selectedIsIncorrect
                    ).opacity(isSelected ? 0.75 : 0.13),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .accessibilityValue(
            selectedIsCorrect ? "선택됨, 정답"
                : selectedIsIncorrect ? "선택됨, 다시 생각해 보기" : ""
        )
        .accessibilityHint(
            activity.kind == .singleChoice
                ? "선택하면 정오답 근거가 바로 표시됩니다."
                : "복수 선택에 포함하거나 제외합니다. 선택 완료 뒤 한 번에 채점합니다."
        )
    }

    private var matchingActivity: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("연결할 카드")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(Array(activity.pairs.reversed())) { pair in
                    Button {
                        selectedRightPairID = pair.id
                    } label: {
                        Label {
                            Text(attributed(pair.right))
                        } icon: {
                            Image(systemName: selectedRightPairID == pair.id
                                ? "hand.point.up.left.fill"
                                : "circle")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    }
                    .buttonStyle(.plain)
                    .background(
                        Color.accentColor.opacity(selectedRightPairID == pair.id ? 0.12 : 0.04),
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                    .draggable(pair.id)
                }
            }

            VStack(spacing: 8) {
                ForEach(activity.pairs) { pair in
                    matchingTarget(pair)
                }
            }

            Text("오른쪽 카드를 끌어 놓거나, 카드를 고른 뒤 연결할 왼쪽 항목을 누르세요. 모든 연결이 채워지면 한 번에 확인합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func matchingTarget(_ pair: V2GameActivity.Pair) -> some View {
        let assignedID = currentMatches[pair.id]
        let assigned = activity.pairs.first { $0.id == assignedID }
        return Button {
            guard let selectedRightPairID else { return }
            onMatchChanged(pair.id, selectedRightPairID)
            self.selectedRightPairID = nil
        } label: {
            HStack(spacing: 10) {
                Text(attributed(pair.left))
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Text(assigned.map { attributed($0.right) } ?? AttributedString("여기에 연결"))
                    .foregroundStyle(assigned == nil ? .secondary : .primary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            guard let rightPairID = items.first else { return false }
            onMatchChanged(pair.id, rightPairID)
            return true
        }
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityHint("연결할 오른쪽 카드를 선택하거나 끌어 놓습니다.")
    }

    private var selectedOptionIDs: Set<String> {
        draft?.selectedOptionIDs ?? response?.selectedOptionIDs ?? []
    }

    private var currentMatches: [String: String] {
        draft?.matches ?? response?.matches ?? [:]
    }

    private var instruction: String {
        switch activity.kind {
        case .singleChoice:
            "카드를 선택하면 바로 근거를 확인할 수 있습니다."
        case .multipleChoice:
            "필요한 카드를 모두 고른 뒤 선택 완료를 누르세요."
        case .matching:
            "모든 연결을 완성하면 한 번에 근거를 확인합니다."
        }
    }

    private func feedback(_ response: V2GameResponse) -> some View {
        let isCorrect = response.isCorrect
        return VStack(alignment: .leading, spacing: 8) {
            Label(
                isCorrect ? "정답 · 근거 확인" : "다시 생각해 보기",
                systemImage: isCorrect
                    ? "checkmark.circle.fill"
                    : "arrow.counterclockwise.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(isCorrect ? Color.green : Color.orange)
            Text(isCorrect ? activity.correctFeedback : activity.incorrectFeedback)
                .fixedSize(horizontal: false, vertical: true)
            Text("시도 \(response.attempts)회 · 답을 바꾸어 다시 확인할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isCorrect ? Color.green : Color.orange).opacity(0.09),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .combine)
    }

    private func cardSymbol(
        selectedIsCorrect: Bool,
        selectedIsIncorrect: Bool
    ) -> String {
        if selectedIsCorrect { return "checkmark.circle.fill" }
        if selectedIsIncorrect { return "xmark.circle.fill" }
        return "circle"
    }

    private func cardAccent(
        selectedIsCorrect: Bool,
        selectedIsIncorrect: Bool
    ) -> Color {
        if selectedIsCorrect { return .green }
        if selectedIsIncorrect { return .orange }
        return .accentColor
    }

    private func attributed(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }
}

/// Stage 2는 결과·단서·조각·흐름·영향의 읽기 행동을 얇은 학습 프레임으로 보여 준다.
struct V2StageTwoLearningComponent: View {
    let page: V2LearningPage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(page.blocks.sorted(by: { $0.order < $1.order })) { block in
                V2ReadingBlock(block: block)
            }
        }
    }
}

private struct V2ReadingBlock: View {
    let block: V2ContentBlock

    private var accent: Color {
        switch block.kind {
        case .mission: .blue
        case .codeStage: .indigo
        case .prediction: .orange
        case .clueScan, .chunking, .flow: .purple
        case .changeExperiment, .transfer: .pink
        case .closure: .green
        default: .teal
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: symbol).foregroundStyle(accent)
                Text(block.title).font(.headline).accessibilityHeading(.h2)
            }
            V2MarkdownContent(markdown: block.markdown)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var symbol: String {
        switch block.kind {
        case .mission: "scope"
        case .codeStage: "chevron.left.forwardslash.chevron.right"
        case .prediction: "eye"
        case .clueScan: "magnifyingglass"
        case .chunking: "square.3.layers.3d"
        case .flow: "arrow.triangle.branch"
        case .changeExperiment: "arrow.left.arrow.right"
        case .reconstruction: "text.bubble"
        case .transfer: "point.3.connected.trianglepath.dotted"
        case .closure: "checkmark.circle"
        default: "lightbulb"
        }
    }
}

struct V2MarkdownContent: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case let .text(value):
                    Text(attributed(value))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                case let .code(language, value):
                    SwiftCodeBlock(
                        code: value,
                        language: language,
                        spokenLabel: "학습 코드"
                    )
                }
            }
        }
    }

    private var segments: [Segment] {
        markdown.components(separatedBy: "```").enumerated().compactMap { index, value in
            guard value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return nil }
            if index.isMultiple(of: 2) { return .text(value) }
            var lines = value.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let language = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "swift"
            if !lines.isEmpty { lines.removeFirst() }
            return .code(language.isEmpty ? "swift" : language, lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func attributed(_ source: String) -> AttributedString {
        var value = source
        value = value.replacingOccurrences(
            of: #"\[\[[^\]|]+\|([^\]]+)\]\]"#,
            with: "$1",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\[\[([^\]]+)\]\]"#,
            with: "$1",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"> \[![^\]]+\]-?\s*"#,
            with: "**도움 · ",
            options: .regularExpression
        )
        value = value.replacingOccurrences(of: "\n> ", with: "**\n")
        return (try? AttributedString(markdown: value)) ?? AttributedString(value)
    }

    private enum Segment {
        case text(String)
        case code(String, String)
    }
}
