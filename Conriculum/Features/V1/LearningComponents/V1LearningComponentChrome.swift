import SwiftUI

struct V1LearningLabeledTextGrid: View {
    let items: [V1LabeledText]
    let accent: Color

    init(
        items: [V1LabeledText],
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

/// macOS의 닫힌 Picker 대신 선택지와 현재 선택을 한 표면에 보여 준다.
/// 같은 버튼을 다시 누르면 선택을 해제할 수 있어 첫 판단을 쉽게 고쳐 볼 수 있다.
struct V1LearningOptionGrid: View {
    let title: String?
    let options: [V1LearningContentItem]
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

    private func optionButton(_ option: V1LearningContentItem) -> some View {
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
