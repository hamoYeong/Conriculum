import SwiftUI

/// Stage 1은 알아보기·대조·보스 전이를 게임 라운드로 보여 준다.
struct V2StageOneGameComponent: View {
    let page: V2LearningPage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(page.blocks.sorted(by: { $0.order < $1.order })) { block in
                V2GameBlock(block: block)
            }
        }
    }
}

private struct V2GameBlock: View {
    let block: V2ContentBlock
    @State private var showsFeedback = false

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

            let parts = V2MarkdownParts(block.markdown)
            V2MarkdownContent(markdown: parts.prompt)

            if let feedback = parts.feedback {
                DisclosureGroup("피드백 확인", isExpanded: $showsFeedback) {
                    V2MarkdownContent(markdown: feedback)
                        .padding(.top, 8)
                }
                .accessibilityHint("선택한 뒤 근거와 해설을 확인합니다.")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.22)) }
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
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            Capsule().fill(accent).frame(width: 4).padding(.vertical, 12)
        }
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

private struct V2MarkdownParts {
    let prompt: String
    let feedback: String?

    init(_ markdown: String) {
        guard let range = markdown.range(of: "\n> [!") else {
            prompt = markdown
            feedback = nil
            return
        }
        prompt = String(markdown[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        feedback = String(markdown[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
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
