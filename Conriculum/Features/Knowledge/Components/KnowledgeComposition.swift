import SwiftUI

/// 표면은 컴포넌트의 경계가 아니라 독립적인 상호작용 문맥을 알릴 때만 쓴다.
enum KnowledgeSectionPresentation: Equatable, Sendable {
    case plain
    case surface
}

/// 지식 상세의 의미 단위를 제목, 간격, 정렬로 구분하는 공용 섹션.
/// 기본 표현은 평면이며 독립적인 편집·검토 단위만 surface를 명시한다.
struct KnowledgeSection<Content: View, Accessory: View>: View {
    let title: String
    let systemImage: String
    let accent: Color
    let presentation: KnowledgeSectionPresentation
    let content: Content
    let accessory: Accessory

    init(
        title: String,
        systemImage: String,
        accent: Color = .accentColor,
        presentation: KnowledgeSectionPresentation = .plain,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
        self.presentation = presentation
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        sectionContainer
            .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var sectionContainer: some View {
        switch presentation {
        case .plain:
            sectionBody

        case .surface:
            sectionBody
                .padding(14)
                .background(
                    Color.primary.opacity(0.035),
                    in: RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                )
        }
    }

    private var sectionBody: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension KnowledgeSection where Accessory == EmptyView {
    init(
        title: String,
        systemImage: String,
        accent: Color = .accentColor,
        presentation: KnowledgeSectionPresentation = .plain,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            accent: accent,
            presentation: presentation,
            accessory: { EmptyView() },
            content: content
        )
    }
}

/// 짧은 라벨과 본문을 묶되 별도 표면을 만들지 않는 정보 블록.
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

/// Concept 정의를 다른 보조 설명과 구분해 읽는 기본 지식 블록.
struct KnowledgeDefinitionBlock: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("개념 한줄 설명", systemImage: "text.alignleft")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("개념 한줄 설명. \(text)")
    }
}

/// 개념을 판단할 때 반복해서 돌아올 핵심 질문을 선형 강조로 표시한다.
struct KnowledgeQuestionBlock: View {
    let question: String
    var title = "핵심 질문"
    var accent: Color = .blue

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(accent)
                .frame(width: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Label(title, systemImage: "questionmark.bubble")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)

                Text(question)
                    .font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(question)")
    }
}

enum KnowledgeItemListStyle: Equatable, Sendable {
    case numbered
    case example
    case caution
}

/// 판단 질문, 예시, 오해처럼 같은 의미를 가진 반복 항목을 행으로 구성한다.
/// 각 항목은 배경 대신 marker, 간격, 타이포그래피로 구분한다.
struct KnowledgeItemList: View {
    let title: String
    let systemImage: String
    let items: [String]
    let style: KnowledgeItemListStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(
                    Array(items.enumerated()),
                    id: \.offset
                ) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        marker(for: index)
                            .frame(width: 18)
                            .accessibilityHidden(true)

                        Text(item)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(title) \(index + 1). \(item)")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func marker(for index: Int) -> some View {
        switch style {
        case .numbered:
            Text("\(index + 1)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.blue)

        case .example:
            Image(systemName: "arrow.turn.down.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.teal)

        case .caution:
            Image(systemName: "exclamationmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.orange)

        }
    }
}

/// 검증·저장·읽기 상태처럼 주변 흐름과 분리해야 하는 피드백만 표면으로 알린다.
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
