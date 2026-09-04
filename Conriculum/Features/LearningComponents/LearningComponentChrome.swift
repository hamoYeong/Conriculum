import SwiftUI

enum LearningBlockRole: Equatable {
    case flow
    case checkpoint
    case task
    case feedback

    var usesSurface: Bool {
        self != .flow
    }
}

/// 학습 단계의 인지적 의도를 헤더 아이콘과 색으로 일관되게 표현한다.
/// 콘텐츠 JSON의 메타데이터가 아니라 SwiftUI 표현 계층에서만 사용한다.
enum LearningIntent: Equatable {
    case recall
    case context
    case observe
    case encode
    case decide
    case apply
    case reflect
    case feedback

    var systemImage: String {
        switch self {
        case .recall: "arrow.counterclockwise"
        case .context: "text.bubble"
        case .observe: "eye"
        case .encode: "book.closed"
        case .decide: "checklist"
        case .apply: "hammer"
        case .reflect: "brain.head.profile"
        case .feedback: "exclamationmark.triangle"
        }
    }

    var accent: Color {
        switch self {
        case .recall: .blue
        case .context: .indigo
        case .observe: .purple
        case .encode: .green
        case .decide: .orange
        case .apply: .cyan
        case .reflect: .teal
        case .feedback: .red
        }
    }
}

struct LearningBlock<Content: View>: View {
    let title: String
    let intent: LearningIntent
    let role: LearningBlockRole
    let content: Content

    init(
        title: String,
        intent: LearningIntent,
        role: LearningBlockRole = .flow,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.intent = intent
        self.role = role
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label {
                Text(title)
                    .font(.headline)
            } icon: {
                Image(systemName: intent.systemImage)
                    .foregroundStyle(intent.accent)
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }
            .accessibilityHeading(.h2)

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if role.usesSurface {
                surfaceBackground
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )
            }
        }
        .overlay {
            if role.usesSurface {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        intent.accent.opacity(surfaceStrokeOpacity),
                        lineWidth: 1
                    )
            }
        }
        .accessibilityElement(children: .contain)
        .focusSection()
    }

    private var surfaceBackground: Color {
        switch role {
        case .flow:
            .clear
        case .checkpoint:
            Color(nsColor: .controlBackgroundColor).opacity(0.52)
        case .task:
            Color(nsColor: .controlBackgroundColor).opacity(0.72)
        case .feedback:
            intent.accent.opacity(0.07)
        }
    }

    private var surfaceStrokeOpacity: Double {
        switch role {
        case .flow: 0
        case .checkpoint: 0.11
        case .task: 0.18
        case .feedback: 0.22
        }
    }
}

struct LearningSupportLabel: View {
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 7) {
            Capsule()
                .fill(accent.opacity(0.72))
                .frame(width: 14, height: 3)
                .accessibilityHidden(true)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

enum LearningCalloutPresentation: Equatable {
    case plain
    case emphasized
}

struct LearningCallout: View {
    let title: String
    let text: String
    let accent: Color
    let presentation: LearningCalloutPresentation

    init(
        title: String,
        text: String,
        accent: Color = .accentColor,
        presentation: LearningCalloutPresentation = .plain
    ) {
        self.title = title
        self.text = text
        self.accent = accent
        self.presentation = presentation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            LearningSupportLabel(title: title, accent: accent)

            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(presentation == .emphasized ? 12 : 0)
        .padding(.vertical, presentation == .plain ? 2 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if presentation == .emphasized {
                accent.opacity(0.065)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 9,
                            style: .continuous
                        )
                    )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(text)")
    }
}

enum SwiftCodeTokenKind: Equatable {
    case plain
    case keyword
    case type
    case string
    case number
    case comment
    case attribute
    case placeholder

    var color: Color {
        switch self {
        case .plain: .primary
        case .keyword: .purple
        case .type: .teal
        case .string: .red
        case .number: .blue
        case .comment: .secondary
        case .attribute: .orange
        case .placeholder: .pink
        }
    }
}

struct SwiftCodeToken: Equatable {
    var text: String
    let kind: SwiftCodeTokenKind
}

enum SwiftCodeHighlighter {
    private static let keywords: Set<String> = [
        "actor", "any", "as", "associatedtype", "async", "await",
        "break", "case", "catch", "class", "continue", "convenience",
        "deinit", "do", "else", "enum", "extension", "fallthrough",
        "false", "fileprivate", "final", "for", "func", "guard", "if",
        "import", "in", "indirect", "init", "inout", "internal", "is",
        "isolated", "lazy", "let", "macro", "mutating", "nil",
        "nonisolated", "nonmutating", "open", "operator", "override",
        "package", "precedencegroup", "private", "protocol", "public",
        "repeat", "required", "rethrows", "return", "self", "Self",
        "some", "static", "struct", "subscript", "super", "switch",
        "throw", "throws", "true", "try", "typealias", "var", "weak",
        "where", "while",
    ]

    private static let standardTypes: Set<String> = [
        "Any", "AnyObject", "Array", "Bool", "Character", "Data",
        "Decimal", "Dictionary", "Double", "Float", "Int", "Int8",
        "Int16", "Int32", "Int64", "Never", "Optional", "Result", "Set",
        "String", "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "URL",
        "UUID", "Void",
    ]

    static func attributedString(for source: String) -> AttributedString {
        tokens(in: source).reduce(into: AttributedString()) { result, token in
            var run = AttributedString(token.text)
            run.foregroundColor = token.kind.color
            result.append(run)
        }
    }

    static func tokens(in source: String) -> [SwiftCodeToken] {
        var tokens: [SwiftCodeToken] = []
        var index = source.startIndex

        while index < source.endIndex {
            if source[index...].hasPrefix("{{") {
                let end = endOfPlaceholder(in: source, from: index)
                append(source[index..<end], as: .placeholder, to: &tokens)
                index = end
            } else if source[index...].hasPrefix("//") {
                let end = source[index...].firstIndex(of: "\n")
                    ?? source.endIndex
                append(source[index..<end], as: .comment, to: &tokens)
                index = end
            } else if source[index...].hasPrefix("/*") {
                let end = endOfBlockComment(in: source, from: index)
                append(source[index..<end], as: .comment, to: &tokens)
                index = end
            } else if source[index...].hasPrefix("\"\"\"") {
                let end = endOfMultilineString(in: source, from: index)
                append(source[index..<end], as: .string, to: &tokens)
                index = end
            } else if source[index] == "\"" {
                let end = endOfString(in: source, from: index)
                append(source[index..<end], as: .string, to: &tokens)
                index = end
            } else if source[index] == "@" || source[index] == "#" {
                let end = endOfPrefixedIdentifier(in: source, from: index)
                append(source[index..<end], as: .attribute, to: &tokens)
                index = end
            } else if source[index].isNumber {
                let end = endOfNumber(in: source, from: index)
                append(source[index..<end], as: .number, to: &tokens)
                index = end
            } else if isIdentifierHead(source[index]) {
                let end = endOfIdentifier(in: source, from: index)
                let word = String(source[index..<end])
                append(word, as: kind(forIdentifier: word), to: &tokens)
                index = end
            } else {
                let end = source.index(after: index)
                append(source[index..<end], as: .plain, to: &tokens)
                index = end
            }
        }

        return tokens
    }

    private static func kind(forIdentifier word: String) -> SwiftCodeTokenKind {
        if keywords.contains(word) {
            return .keyword
        }
        if standardTypes.contains(word) || word.first?.isUppercase == true {
            return .type
        }
        return .plain
    }

    private static func endOfIdentifier(
        in source: String,
        from start: String.Index
    ) -> String.Index {
        var index = source.index(after: start)
        while index < source.endIndex, isIdentifierBody(source[index]) {
            index = source.index(after: index)
        }
        return index
    }

    private static func endOfPrefixedIdentifier(
        in source: String,
        from start: String.Index
    ) -> String.Index {
        let next = source.index(after: start)
        guard next < source.endIndex, isIdentifierHead(source[next]) else {
            return next
        }
        return endOfIdentifier(in: source, from: next)
    }

    private static func endOfNumber(
        in source: String,
        from start: String.Index
    ) -> String.Index {
        var index = source.index(after: start)
        while index < source.endIndex {
            let character = source[index]
            guard character.isLetter || character.isNumber
                    || character == "_" || character == "."
            else { break }
            index = source.index(after: index)
        }
        return index
    }

    private static func endOfString(
        in source: String,
        from start: String.Index
    ) -> String.Index {
        var index = source.index(after: start)
        var isEscaped = false
        while index < source.endIndex {
            let character = source[index]
            index = source.index(after: index)
            if character == "\"", !isEscaped {
                break
            }
            if character == "\\" {
                isEscaped.toggle()
            } else {
                isEscaped = false
            }
        }
        return index
    }

    private static func endOfMultilineString(
        in source: String,
        from start: String.Index
    ) -> String.Index {
        var index = source.index(start, offsetBy: 3)
        while index < source.endIndex {
            if source[index...].hasPrefix("\"\"\"") {
                return source.index(index, offsetBy: 3)
            }
            index = source.index(after: index)
        }
        return source.endIndex
    }

    private static func endOfBlockComment(
        in source: String,
        from start: String.Index
    ) -> String.Index {
        var index = source.index(start, offsetBy: 2)
        var depth = 1
        while index < source.endIndex {
            if source[index...].hasPrefix("/*") {
                depth += 1
                index = source.index(index, offsetBy: 2)
            } else if source[index...].hasPrefix("*/") {
                depth -= 1
                index = source.index(index, offsetBy: 2)
                if depth == 0 {
                    return index
                }
            } else {
                index = source.index(after: index)
            }
        }
        return source.endIndex
    }

    private static func endOfPlaceholder(
        in source: String,
        from start: String.Index
    ) -> String.Index {
        var index = source.index(start, offsetBy: 2)
        while index < source.endIndex {
            if source[index...].hasPrefix("}}") {
                return source.index(index, offsetBy: 2)
            }
            index = source.index(after: index)
        }
        return source.endIndex
    }

    private static func isIdentifierHead(_ character: Character) -> Bool {
        character.isLetter || character == "_"
    }

    private static func isIdentifierBody(_ character: Character) -> Bool {
        isIdentifierHead(character) || character.isNumber
    }

    private static func append(
        _ text: some StringProtocol,
        as kind: SwiftCodeTokenKind,
        to tokens: inout [SwiftCodeToken]
    ) {
        guard !text.isEmpty else { return }
        if tokens.last?.kind == kind {
            tokens[tokens.index(before: tokens.endIndex)].text += String(text)
        } else {
            tokens.append(SwiftCodeToken(text: String(text), kind: kind))
        }
    }
}

struct SwiftCodeText: View {
    let code: String
    let textStyle: Font.TextStyle

    init(
        _ code: String,
        textStyle: Font.TextStyle = .body
    ) {
        self.code = code
        self.textStyle = textStyle
    }

    var body: some View {
        Text(SwiftCodeHighlighter.attributedString(for: code))
            .font(.system(textStyle, design: .monospaced))
    }
}

struct SwiftCodeBlock: View {
    let code: String
    let language: String
    let spokenLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(language.uppercased())
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

            Divider()

            ScrollView(.horizontal) {
                SwiftCodeText(code)
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    Color(nsColor: .separatorColor).opacity(0.55),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityValue(code)
        .accessibilityHint("가로로 스크롤하여 긴 코드를 확인할 수 있습니다.")
    }
}

struct LearningNumberedRow: View {
    let number: Int
    let title: String?
    let text: String
    let accent: Color

    init(
        number: Int,
        title: String? = nil,
        text: String,
        accent: Color = .accentColor
    ) {
        self.number = number
        self.title = title
        self.text = text
        self.accent = accent
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 26, height: 26)
                .background(accent.opacity(0.10), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                if let title {
                    Text(title)
                        .font(.callout.weight(.semibold))
                }

                Text(text)
                    .foregroundStyle(title == nil ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            ["\(number)번째", title, text]
                .compactMap { $0 }
                .joined(separator: ". ")
        )
    }
}

struct LearningLabeledTextGrid: View {
    let items: [LabeledText]
    let accent: Color

    init(
        items: [LabeledText],
        accent: Color = .accentColor
    ) {
        self.items = items
        self.accent = accent
    }

    var body: some View {
        LazyVGrid(
            columns: columns,
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 5) {
                    if let label = item.label {
                        LearningSupportLabel(
                            title: label,
                            accent: accent
                        )
                            .accessibilityAddTraits(.isHeader)
                    }

                    Text(item.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var columns: [GridItem] {
        if items.count == 1 {
            return [GridItem(.flexible(), alignment: .top)]
        }
        return [
            GridItem(.adaptive(minimum: 180), spacing: 12, alignment: .top)
        ]
    }
}

/// macOS의 닫힌 Picker 대신 선택지와 현재 선택을 한 표면에 보여 주는 공통 입력.
/// 같은 버튼을 다시 누르면 선택을 해제할 수 있어 첫 판단을 쉽게 고쳐 볼 수 있다.
struct LearningOptionGrid: View {
    let title: String?
    let options: [LearningContentItem]
    @Binding var selection: String
    var accent: Color = .accentColor
    var allowsEmptySelection = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: 128, maximum: 240),
                        spacing: 8,
                        alignment: .top
                    )
                ],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(options, id: \.id) { option in
                    optionButton(option)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func optionButton(_ option: LearningContentItem) -> some View {
        let isSelected = selection == option.id

        return Button {
            if isSelected, allowsEmptySelection {
                selection = ""
            } else {
                selection = option.id
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(isSelected ? accent : .secondary)
                .accessibilityHidden(true)

                Text(option.text)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                isSelected
                    ? accent.opacity(0.11)
                    : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isSelected
                            ? accent.opacity(0.45)
                            : Color(nsColor: .separatorColor).opacity(0.65),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.text)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
        .accessibilityHint(
            isSelected && allowsEmptySelection
                ? "다시 누르면 선택을 해제합니다."
                : "이 항목을 선택합니다."
        )
    }
}
