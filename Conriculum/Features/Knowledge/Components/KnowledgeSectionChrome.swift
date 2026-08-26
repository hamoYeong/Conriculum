import SwiftUI

/// 지식 상세의 의미 단위를 일관된 GroupBox로 표현한다.
/// Content와 accessory만 받아 Feature/Store에 의존하지 않는다.
struct KnowledgeSectionChrome<Content: View, Accessory: View>: View {
    let title: String
    let systemImage: String
    let accent: Color
    let content: Content
    let accessory: Accessory

    init(
        title: String,
        systemImage: String,
        accent: Color = .accentColor,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        GroupBox {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)
                }
                .font(.headline)
                .accessibilityHeading(.h2)

                Spacer(minLength: 8)
                accessory
            }
        }
        .accessibilityElement(children: .contain)
    }
}

extension KnowledgeSectionChrome where Accessory == EmptyView {
    init(
        title: String,
        systemImage: String,
        accent: Color = .accentColor,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            accent: accent,
            accessory: { EmptyView() },
            content: content
        )
    }
}

/// 짧은 label과 본문을 묶는 지식 상세의 공통 행.
struct KnowledgeLabeledText: View {
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(text)")
    }
}

/// 검증·저장·읽기 상태를 같은 시각 언어로 알리는 공통 banner.
struct KnowledgeMessageBanner: View {
    let title: String
    let message: String
    let systemImage: String
    let accent: Color

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
        }
        .foregroundStyle(accent)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            accent.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}
