import SwiftUI

struct LearningBlock<Content: View>: View {
    let title: String
    let systemImage: String
    let accent: Color
    let content: Content

    init(
        title: String,
        systemImage: String,
        accent: Color = .accentColor,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
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
            }
            .accessibilityAddTraits(.isHeader)

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor).opacity(0.72),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
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
        HStack(alignment: .top, spacing: 12) {
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            accent.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
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
                    }

                    Text(item.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color(nsColor: .textBackgroundColor).opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
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
