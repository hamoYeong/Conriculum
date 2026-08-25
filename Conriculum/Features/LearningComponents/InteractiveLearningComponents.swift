import Foundation
import SwiftUI

struct CardSortingComponent: View {
    let content: CardSortingContent
    let activity: LearningActivityInput
    @State private var selectedCardID: String?

    var body: some View {
        LearningBlock(
            title: "분류하기",
            systemImage: "rectangle.3.group",
            accent: .blue
        ) {
            Text(content.interaction)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Text("카드")
                    .font(.subheadline.weight(.semibold))

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 190), spacing: 10)
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(content.cards, id: \.id) { card in
                        cardButton(card)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("선택한 카드를 놓을 영역")
                    .font(.subheadline.weight(.semibold))

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 210), spacing: 10)
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(content.groups, id: \.id) { group in
                        groupButton(group)
                    }
                }
            }

            TextField(
                "분류한 이유를 한 문장으로 적기",
                text: activity.textBinding(for: LearningActivityFieldKey.reason),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("분류한 이유")
            .accessibilityHint("분류에 사용한 기준을 한 문장으로 입력합니다.")

            ActivityCriteriaView(
                title: "완료 기준",
                criteria: content.completionCriteria
            )
            ActivityCriteriaView(
                title: "생각을 점검할 기준",
                criteria: content.feedbackCriteria,
                systemImage: "arrow.triangle.2.circlepath",
                accent: .orange
            )
        }
    }

    private func cardButton(_ card: LearningContentItem) -> some View {
        let assignment = assignedGroup(for: card.id)
        let isSelected = selectedCardID == card.id

        return Button {
            selectedCardID = isSelected ? nil : card.id
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(card.text)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let assignment {
                        Text("배치: \(assignment.text)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("아직 배치하지 않음")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .draggable(card.id)
        .accessibilityLabel(card.text)
        .accessibilityValue(
            [
                isSelected ? "선택됨" : "선택 안 됨",
                assignment.map { "\($0.text)에 배치됨" } ?? "배치 안 됨",
            ]
            .joined(separator: ", ")
        )
        .accessibilityHint("선택한 뒤 분류 영역 버튼을 누르거나 영역으로 드래그합니다.")
    }

    private func groupButton(_ group: LearningContentItem) -> some View {
        Button {
            guard let selectedCardID else { return }
            assign(cardID: selectedCardID, to: group.id)
        } label: {
            HStack {
                Label(group.text, systemImage: "tray")
                Spacer()
                Text("\(assignedCardCount(to: group.id))개")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .disabled(selectedCardID == nil)
        .dropDestination(for: String.self) { cardIDs, _ in
            guard let cardID = cardIDs.first,
                  content.cards.contains(where: { $0.id == cardID })
            else { return false }
            assign(cardID: cardID, to: group.id)
            return true
        }
        .accessibilityLabel("분류 영역. \(group.text)")
        .accessibilityValue("배치된 카드 \(assignedCardCount(to: group.id))개")
        .accessibilityHint("선택한 카드를 이 영역에 배치합니다.")
    }

    private func assignedGroup(
        for cardID: String
    ) -> LearningContentItem? {
        let groupID = activity.value(
            for: LearningActivityFieldKey.card(cardID)
        )
        return content.groups.first { $0.id == groupID }
    }

    private func assignedCardCount(to groupID: String) -> Int {
        content.cards.count { card in
            activity.value(for: LearningActivityFieldKey.card(card.id))
                == groupID
        }
    }

    private func assign(cardID: String, to groupID: String) {
        activity.updating(
            key: LearningActivityFieldKey.card(cardID),
            values: [groupID]
        )
        selectedCardID = nil
    }
}

struct MatchingComponent: View {
    let content: MatchingContent
    let activity: LearningActivityInput

    var body: some View {
        LearningBlock(
            title: "연결하기",
            systemImage: "point.3.connected.trianglepath.dotted",
            accent: .purple
        ) {
            LearningCallout(
                title: "연결 규칙",
                text: content.rule,
                systemImage: "link",
                accent: .purple
            )

            VStack(alignment: .leading, spacing: 14) {
                ForEach(content.leftItems, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.text)
                            .font(.callout.weight(.semibold))

                        Picker(
                            "\(item.text)에 연결할 항목",
                            selection: activity.textBinding(
                                for: LearningActivityFieldKey.match(item.id)
                            )
                        ) {
                            Text("선택 안 함").tag("")
                            ForEach(content.rightItems, id: \.id) { target in
                                Text(target.text).tag(target.id)
                            }
                        }
                        .labelsHidden()
                        .accessibilityLabel("\(item.text)에 연결할 항목")
                    }
                }
            }

            TextField(
                "표기의 차이 한 가지 설명하기",
                text: activity.textBinding(for: LearningActivityFieldKey.reason),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("연결한 표기의 차이")

            ActivityCriteriaView(
                title: "완료 기준",
                criteria: content.completionCriteria
            )
        }
    }
}

struct ChoiceWithReasonComponent: View {
    let content: ChoiceWithReasonContent
    let activity: LearningActivityInput

    var body: some View {
        LearningBlock(
            title: "고르고 설명하기",
            systemImage: "checkmark.circle",
            accent: .indigo
        ) {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(content.questions, id: \.id) { question in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question.prompt)
                            .font(.callout.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        Picker(
                            question.prompt,
                            selection: activity.textBinding(
                                for: LearningActivityFieldKey.choice(question.id)
                            )
                        ) {
                            Text("선택 안 함").tag("")
                            ForEach(question.options, id: \.id) { option in
                                Text(option.text).tag(option.id)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .accessibilityLabel(question.prompt)
                    }
                }
            }

            TextField(
                content.reasonPrompt,
                text: activity.textBinding(for: LearningActivityFieldKey.reason),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(content.reasonPrompt)

            ActivityCriteriaView(
                title: "생각을 점검할 기준",
                criteria: content.feedbackCriteria,
                systemImage: "arrow.triangle.2.circlepath",
                accent: .orange
            )
        }
    }
}

struct FillInBlankComponent: View {
    let content: FillInBlankContent
    let activity: LearningActivityInput

    var body: some View {
        LearningBlock(
            title: "빈칸 채우기",
            systemImage: "character.cursor.ibeam",
            accent: .teal
        ) {
            ScrollView(.horizontal) {
                Text(verbatim: content.template)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(14)
            }
            .scrollIndicators(.visible)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .accessibilityLabel("빈칸이 포함된 Swift 코드")
            .accessibilityValue(content.template)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(content.blanks, id: \.id) { blank in
                    if blank.options.isEmpty {
                        TextField(
                            blank.placeholder,
                            text: activity.textBinding(
                                for: LearningActivityFieldKey.blank(blank.id)
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel(blank.placeholder)
                    } else {
                        Picker(
                            blank.placeholder,
                            selection: activity.textBinding(
                                for: LearningActivityFieldKey.blank(blank.id)
                            )
                        ) {
                            Text("선택 안 함").tag("")
                            ForEach(blank.options, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .accessibilityLabel(blank.placeholder)
                    }
                }
            }

            ActivityCriteriaView(
                title: "완료 기준",
                criteria: content.completionCriteria
            )
        }
    }
}

struct CodeAssemblyComponent: View {
    let content: CodeAssemblyContent
    let activity: LearningActivityInput

    private var starterLines: [String] {
        content.starterCode.components(separatedBy: .newlines)
    }

    var body: some View {
        LearningBlock(
            title: "코드 조립하기",
            systemImage: "square.3.layers.3d",
            accent: .cyan
        ) {
            Text("각 줄의 역할에 맞는 이름을 선택하거나 이름 조각을 줄로 드래그합니다.")
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(content.pieces, id: \.id) { piece in
                        Text(piece.text)
                            .font(.callout.monospaced())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Color.cyan.opacity(0.10),
                                in: Capsule()
                            )
                            .draggable(piece.id)
                            .accessibilityLabel("이름 조각 \(piece.text)")
                            .accessibilityHint("코드 줄로 드래그할 수 있습니다.")
                    }
                }
            }
            .scrollIndicators(.hidden)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(starterLines.enumerated()), id: \.offset) {
                    index,
                    line in
                    codeLine(line, at: index)
                }
            }

            if !content.fixedParts.isEmpty {
                LearningCallout(
                    title: "바꾸지 않는 부분",
                    text: content.fixedParts.joined(separator: ", "),
                    systemImage: "lock",
                    accent: .secondary
                )
            }

            ActivityCriteriaView(
                title: "완료 기준",
                criteria: content.completionCriteria
            )
        }
    }

    private func codeLine(_ line: String, at index: Int) -> some View {
        let key = LearningActivityFieldKey.codeLine(index)

        return VStack(alignment: .leading, spacing: 7) {
            Text(verbatim: line)
                .font(.callout.monospaced())
                .textSelection(.enabled)

            Picker(
                "\(index + 1)번째 줄의 이름",
                selection: activity.textBinding(for: key)
            ) {
                Text("이름 선택 안 함").tag("")
                ForEach(content.pieces, id: \.id) { piece in
                    Text(piece.text).tag(piece.id)
                }
            }
            .accessibilityLabel("\(index + 1)번째 줄에 사용할 이름")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .textBackgroundColor).opacity(0.55),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .dropDestination(for: String.self) { pieceIDs, _ in
            guard let pieceID = pieceIDs.first,
                  content.pieces.contains(where: { $0.id == pieceID })
            else { return false }
            activity.updating(key: key, values: [pieceID])
            return true
        }
        .accessibilityHint("Picker로 선택하거나 이름 조각을 이 줄로 드래그합니다.")
    }
}

struct FreeResponseComponent: View {
    let content: FreeResponseContent
    let activity: LearningActivityInput
    @State private var isShowingExample = false

    private var response: String {
        activity.value(for: LearningActivityFieldKey.response)
    }

    var body: some View {
        LearningBlock(
            title: "직접 설명하기",
            systemImage: "square.and.pencil",
            accent: .orange
        ) {
            Text(content.prompt)
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            LearningCallout(
                title: "작성 형식",
                text: content.inputFormat,
                systemImage: "text.alignleft",
                accent: .orange
            )

            TextEditor(
                text: activity.textBinding(
                    for: LearningActivityFieldKey.response
                )
            )
            .font(.body)
            .frame(minHeight: 120)
            .padding(8)
            .background(
                Color(nsColor: .textBackgroundColor),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
            .accessibilityLabel("자유 응답")
            .accessibilityHint(content.inputFormat)

            ActivityCriteriaView(
                title: "응답에 포함할 근거",
                criteria: content.requiredEvidence,
                systemImage: "quote.bubble",
                accent: .orange
            )

            Button(isShowingExample ? "비교 예시 숨기기" : "응답 작성 후 예시 보기") {
                isShowingExample.toggle()
            }
            .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityHint("내 응답을 작성한 뒤 참고 예시를 비교합니다.")

            if isShowingExample {
                LearningCallout(
                    title: "비교 예시",
                    text: content.exampleAfterSubmission,
                    systemImage: "lightbulb",
                    accent: .yellow
                )
            }
        }
    }
}

struct RecallCheckComponent: View {
    let content: RecallCheckContent
    let activity: LearningActivityInput

    var body: some View {
        LearningBlock(
            title: "되짚어 보기",
            systemImage: "brain.head.profile",
            accent: .green
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(content.questions.enumerated()), id: \.offset) {
                    index,
                    question in
                    LearningNumberedRow(
                        number: index + 1,
                        text: question,
                        accent: .green
                    )
                }
            }

            LearningCallout(
                title: "비교 대상",
                text: content.comparisonTarget,
                systemImage: "arrow.left.arrow.right",
                accent: .green
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("남길 기록")
                    .font(.subheadline.weight(.semibold))

                ForEach(Array(content.recordFields.enumerated()), id: \.offset) {
                    index,
                    field in
                    TextField(
                        field,
                        text: activity.textBinding(
                            for: LearningActivityFieldKey.recall(index)
                        ),
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(field)
                }
            }
        }
    }
}
