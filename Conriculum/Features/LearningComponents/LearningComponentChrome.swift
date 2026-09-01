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
