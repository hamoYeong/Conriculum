import SwiftUI

enum LearningBlockRole: Equatable {
    case information
    case activity
    case feedback

    var usesSurface: Bool {
        self != .information
    }
}

struct LearningBlock<Content: View>: View {
    let title: String
    let systemImage: String
    let accent: Color
    let role: LearningBlockRole
    let content: Content

    init(
        title: String,
        systemImage: String,
        accent: Color = .accentColor,
        role: LearningBlockRole = .information,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
        self.role = role
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label {
                Text(title)
                    .font(.headline)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(accent)
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }
            .accessibilityHeading(.h2)

            content
        }
        .padding(role.usesSurface ? 20 : 0)
        .padding(.vertical, role.usesSurface ? 0 : 4)
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
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .contain)
        .focusSection()
    }

    private var surfaceBackground: Color {
        switch role {
        case .information:
            .clear
        case .activity:
            Color(nsColor: .controlBackgroundColor).opacity(0.72)
        case .feedback:
            accent.opacity(0.07)
        }
    }
}

struct LearningAccentSection<Content: View>: View {
    let accent: Color
    let content: Content

    init(
        accent: Color = .accentColor,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .padding(.leading, 13)
            .padding(.vertical, 2)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent.opacity(0.62))
                    .frame(width: 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LearningCallout: View {
    let title: String
    let text: String
    let systemImage: String
    let accent: Color

    init(
        title: String,
        text: String,
        systemImage: String,
        accent: Color = .accentColor
    ) {
        self.title = title
        self.text = text
        self.systemImage = systemImage
        self.accent = accent
    }

    var body: some View {
        LearningAccentSection(accent: accent) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(accent)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(text)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                            .accessibilityAddTraits(.isHeader)
                    }

                    Text(item.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 12)
                .padding(.vertical, 3)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(accent.opacity(0.42))
                        .frame(width: 2)
                }
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
