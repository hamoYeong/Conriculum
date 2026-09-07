import Foundation
import SwiftUI

struct V1CardSortingComponent: View {
    let content: V1CardSortingContent
    let activity: V1LearningActivityInput
    @State private var selectedCardID: String?

    var body: some View {
        LearningBlock(
            title: "기준으로 분류하기",
            intent: .apply,
            role: .task
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
            .focusSection()

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
            .focusSection()

            TextField(
                "분류한 이유를 한 문장으로 적기",
                text: activity.textBinding(for: V1LearningActivityFieldKey.reason),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("분류한 이유")
            .accessibilityHint("분류에 사용한 기준을 한 문장으로 입력합니다.")

            V1ActivityCriteriaView(
                title: "완료 기준",
                criteria: content.completionCriteria
            )
            V1ActivityCriteriaView(
                title: "생각을 점검할 기준",
                criteria: content.feedbackCriteria,
                accent: .orange
            )

            V1ActivityDraftStatusView(activity: activity)
        }
    }

    private func cardButton(_ card: V1LearningContentItem) -> some View {
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
        .accessibilityActions {
            ForEach(content.groups, id: \.id) { group in
                Button("\(group.text)에 배치") {
                    assign(cardID: card.id, to: group.id)
                }
            }
        }
    }

    private func groupButton(_ group: V1LearningContentItem) -> some View {
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
        .accessibilityHint(
            selectedCardID == nil
                ? "먼저 카드 버튼을 선택합니다."
                : "선택한 카드를 이 영역에 배치합니다."
        )
    }

    private func assignedGroup(
        for cardID: String
    ) -> V1LearningContentItem? {
        let groupID = activity.value(
            for: V1LearningActivityFieldKey.card(cardID)
        )
        return content.groups.first { $0.id == groupID }
    }

    private func assignedCardCount(to groupID: String) -> Int {
        content.cards.count { card in
            activity.value(for: V1LearningActivityFieldKey.card(card.id))
                == groupID
        }
    }

    private func assign(cardID: String, to groupID: String) {
        updateAssignment(cardID: cardID, to: groupID)
        selectedCardID = nil
    }

    func updateAssignment(cardID: String, to groupID: String) {
        activity.updating(
            key: V1LearningActivityFieldKey.card(cardID),
            values: [groupID]
        )
    }
}

struct V1MatchingComponent: View {
    let content: V1MatchingContent
    let activity: V1LearningActivityInput

    var body: some View {
        LearningBlock(
            title: "짝을 찾아 연결하기",
            intent: .apply,
            role: .task
        ) {
            LearningCallout(
                title: "연결 규칙",
                text: content.rule,
                accent: .purple
            )

            VStack(alignment: .leading, spacing: 14) {
                ForEach(content.leftItems, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.text)
                            .font(.callout.weight(.semibold))

                        LearningOptionGrid(
                            title: "연결할 항목",
                            options: content.rightItems,
                            selection: activity.textBinding(
                                for: V1LearningActivityFieldKey.match(item.id)
                            ),
                            accent: .purple
                        )
                        .accessibilityLabel("\(item.text)에 연결할 항목")
                        .accessibilityHint(
                            "연결할 오른쪽 항목을 선택합니다."
                        )
                    }
                }
            }

            TextField(
                "표기의 차이 한 가지 설명하기",
                text: activity.textBinding(for: V1LearningActivityFieldKey.reason),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel("연결한 표기의 차이")

            V1ActivityCriteriaView(
                title: "완료 기준",
                criteria: content.completionCriteria
            )

            V1ActivityDraftStatusView(activity: activity)
        }
    }
}

struct V1ChoiceWithReasonComponent: View {
    let content: V1ChoiceWithReasonContent
    let activity: V1LearningActivityInput

    var body: some View {
        LearningBlock(
            title: "고르고 설명하기",
            intent: .decide,
            role: .task
        ) {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(content.questions, id: \.id) { question in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question.prompt)
                            .font(.callout.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)

                        LearningOptionGrid(
                            title: nil,
                            options: question.options,
                            selection: activity.textBinding(
                                for: V1LearningActivityFieldKey.choice(question.id)
                            ),
                            accent: .blue
                        )
                        .accessibilityLabel(question.prompt)
                        .accessibilityHint("답을 하나 선택합니다.")
                    }
                }
            }

            TextField(
                content.reasonPrompt,
                text: activity.textBinding(for: V1LearningActivityFieldKey.reason),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(content.reasonPrompt)

            V1ActivityCriteriaView(
                title: "생각을 점검할 기준",
                criteria: content.feedbackCriteria,
                accent: .orange
            )

            V1ActivityDraftStatusView(activity: activity)
        }
    }
}

struct V1FillInBlankComponent: View {
    let content: V1FillInBlankContent
    let activity: V1LearningActivityInput

    var body: some View {
        LearningBlock(
            title: "빈칸 채워 완성하기",
            intent: .apply,
            role: .task
        ) {
            SwiftCodeBlock(
                code: content.template,
                language: "Swift",
                spokenLabel: "빈칸이 포함된 Swift 코드"
            )

            VStack(alignment: .leading, spacing: 12) {
                ForEach(content.blanks, id: \.id) { blank in
                    if blank.options.isEmpty {
                        TextField(
                            blank.placeholder,
                            text: activity.textBinding(
                                for: V1LearningActivityFieldKey.blank(blank.id)
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel(blank.placeholder)
                        .accessibilityHint("빈칸에 들어갈 내용을 입력합니다.")
                    } else {
                        LearningOptionGrid(
                            title: blank.placeholder,
                            options: blank.options.map {
                                V1LearningContentItem(id: $0, text: $0)
                            },
                            selection: activity.textBinding(
                                for: V1LearningActivityFieldKey.blank(blank.id)
                            ),
                            accent: .orange
                        )
                        .accessibilityLabel(blank.placeholder)
                        .accessibilityHint("빈칸에 들어갈 항목을 선택합니다.")
                    }
                }
            }

            V1ActivityCriteriaView(
                title: "완료 기준",
                criteria: content.completionCriteria
            )

            V1ActivityDraftStatusView(activity: activity)
        }
    }
}

struct V1CodeAssemblyComponent: View {
    let content: V1CodeAssemblyContent
    let activity: V1LearningActivityInput

    private var starterLines: [String] {
        content.starterCode.components(separatedBy: .newlines)
    }

    var body: some View {
        LearningBlock(
            title: "코드 조립하기",
            intent: .apply,
            role: .task
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("사용할 수 있는 이름 조각")
            .accessibilityValue(
                content.pieces.map(\.text).joined(separator: ", ")
            )
            .accessibilityHint(
                "아래 각 코드 줄의 선택 메뉴에서 이름을 고를 수 있습니다."
            )

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
                    accent: .secondary
                )
            }

            V1ActivityCriteriaView(
                title: "완료 기준",
                criteria: content.completionCriteria
            )

            V1ActivityDraftStatusView(activity: activity)
        }
    }

    private func codeLine(_ line: String, at index: Int) -> some View {
        let key = V1LearningActivityFieldKey.codeLine(index)

        return VStack(alignment: .leading, spacing: 7) {
            SwiftCodeText(line, textStyle: .callout)
                .textSelection(.enabled)

            LearningOptionGrid(
                title: "이 줄에 사용할 이름",
                options: content.pieces,
                selection: selectionBinding(at: index),
                accent: .cyan
            )
            .accessibilityLabel("\(index + 1)번째 줄에 사용할 이름")
            .accessibilityHint(
                "이름을 선택합니다. 드래그하지 않고도 완료할 수 있습니다."
            )
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
    }

    func selectionBinding(at index: Int) -> Binding<String> {
        activity.textBinding(
            for: V1LearningActivityFieldKey.codeLine(index)
        )
    }
}

struct V1FreeResponseComponent: View {
    let content: V1FreeResponseContent
    let activity: V1LearningActivityInput
    @State private var isShowingExample = false

    private var response: String {
        activity.value(for: V1LearningActivityFieldKey.response)
    }

    var body: some View {
        LearningBlock(
            title: "직접 설명하기",
            intent: .apply,
            role: .task
        ) {
            Text(content.prompt)
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            LearningCallout(
                title: "작성 형식",
                text: content.inputFormat,
                accent: .orange
            )

            TextEditor(
                text: activity.textBinding(
                    for: V1LearningActivityFieldKey.response
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

            V1ActivityCriteriaView(
                title: "응답에 포함할 근거",
                criteria: content.requiredEvidence,
                accent: .orange
            )

            Button(isShowingExample ? "비교 예시 숨기기" : "응답 작성 후 예시 보기") {
                isShowingExample.toggle()
            }
            .disabled(response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityValue(isShowingExample ? "표시됨" : "숨겨짐")
            .accessibilityHint("내 응답을 작성한 뒤 참고 예시를 비교합니다.")

            if isShowingExample {
                LearningCallout(
                    title: "비교 예시",
                    text: content.exampleAfterSubmission,
                    accent: .yellow,
                    presentation: .emphasized
                )
            }

            V1ActivityDraftStatusView(activity: activity)
        }
    }
}

struct V1RecallCheckComponent: View {
    let content: V1RecallCheckContent
    let activity: V1LearningActivityInput

    var body: some View {
        LearningBlock(
            title: "되짚어 보기",
            intent: .reflect,
            role: .task
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
                            for: V1LearningActivityFieldKey.recall(index)
                        ),
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(field)
                    .accessibilityHint("되짚어 본 내용을 기록합니다.")
                }
            }

            V1ActivityDraftStatusView(activity: activity)
        }
    }
}

struct V1LearningCompassComponent: View {
    let content: V1LearningCompassContent
    let activity: V1LearningActivityInput

    private let confidenceLevels = ["낮음", "중간", "높음"]

    var body: some View {
        LearningBlock(
            title: "이번 판단의 방향",
            intent: .context,
            role: .checkpoint
        ) {
            LearningCallout(
                title: "이전 학습과 연결",
                text: content.previousConnection,
                accent: .indigo
            )

            LearningCallout(
                title: "지금의 핵심 질문",
                text: content.coreQuestion,
                accent: .indigo,
                presentation: .emphasized
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(content.firstPredictionPrompt)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                TextField(
                    "첫 예상을 근거와 함께 적기",
                    text: activity.textBinding(
                        for: V1LearningActivityFieldKey.compassPrediction
                    ),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("첫 예상")
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(content.confidencePrompt)
                    .font(.callout.weight(.semibold))

                HStack(spacing: 8) {
                    ForEach(confidenceLevels, id: \.self) { level in
                        LearningSelectionChip(
                            title: level,
                            isSelected: activity.value(
                                for: V1LearningActivityFieldKey
                                    .compassConfidence
                            ) == level
                        ) {
                            activity.updating(
                                key: V1LearningActivityFieldKey
                                    .compassConfidence,
                                values: [level]
                            )
                        }
                    }
                }

                TextField(
                    "그 확신을 고른 이유",
                    text: activity.textBinding(
                        for: V1LearningActivityFieldKey
                            .compassConfidenceReason
                    ),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
            }

            V1ActivityCriteriaView(
                title: "이 페이지의 완료 증거",
                criteria: content.completionEvidence,
                accent: .green
            )

            V1ActivityDraftStatusView(activity: activity)
        }
    }
}

struct V1LearningClosureComponent: View {
    let content: V1LearningClosureContent
    let activity: V1LearningActivityInput

    private let confidenceLevels = ["낮음", "중간", "높음"]

    var body: some View {
        LearningBlock(
            title: "처음과 지금 비교하기",
            intent: .reflect,
            role: .task
        ) {
            LearningCallout(
                title: "처음 기록",
                text: content.firstPredictionReference,
                accent: .teal
            )

            responseField(
                prompt: content.finalExplanationPrompt,
                placeholder: "수행 뒤의 설명",
                key: V1LearningActivityFieldKey.reflectionFinalExplanation
            )

            VStack(alignment: .leading, spacing: 9) {
                Text(content.confidenceChangePrompt)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(confidenceLevels, id: \.self) { level in
                        LearningSelectionChip(
                            title: level,
                            isSelected: activity.value(
                                for: V1LearningActivityFieldKey
                                    .reflectionConfidence
                            ) == level
                        ) {
                            activity.updating(
                                key: V1LearningActivityFieldKey
                                    .reflectionConfidence,
                                values: [level]
                            )
                        }
                    }
                }

                TextField(
                    "확신이 달라진 근거",
                    text: activity.textBinding(
                        for: V1LearningActivityFieldKey
                            .reflectionConfidenceReason
                    ),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
            }

            responseField(
                prompt: content.changedCriterionPrompt,
                placeholder: "버린 기준과 새로 쓴 기준",
                key: V1LearningActivityFieldKey.reflectionChangedCriterion
            )

            responseField(
                prompt: content.nextUsePrompt,
                placeholder: "다음에 이 판단을 쓸 상황",
                key: V1LearningActivityFieldKey.reflectionNextUse
            )

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text(content.completionQuestion)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        assessmentButton(.ready)
                        assessmentButton(.retry)
                    }
                    VStack(spacing: 8) {
                        assessmentButton(.ready)
                        assessmentButton(.retry)
                    }
                }
            }

            V1ActivityCriteriaView(
                title: "설명에 포함할 근거",
                criteria: content.requiredEvidence,
                accent: .green
            )

            LearningCallout(
                title: "다시 확인할 때",
                text: content.retryCondition,
                accent: .orange,
                presentation: .emphasized
            )

            V1ActivityDraftStatusView(activity: activity)
        }
    }

    private func assessmentButton(
        _ option: V1CompletionSelfAssessment
    ) -> some View {
        LearningSelectionChip(
            title: option.title,
            isSelected: activity.value(
                for: V1LearningActivityFieldKey.completionAssessment
            ) == option.rawValue
        ) {
            activity.updating(
                key: V1LearningActivityFieldKey.completionAssessment,
                values: [option.rawValue]
            )
        }
    }

    private func responseField(
        prompt: String,
        placeholder: String,
        key: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(prompt)
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            TextField(
                placeholder,
                text: activity.textBinding(for: key),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(prompt)
        }
    }
}

struct V1SemanticChunkReadingComponent: View {
    let content: V1SemanticChunkReadingContent
    let activity: V1LearningActivityInput

    private var selectedElementIDs: [String] {
        activity.values(
            for: V1LearningActivityFieldKey.semanticChunkSelection
        )
    }

    var body: some View {
        LearningBlock(
            title: "의미 단위 조각으로 읽기",
            intent: .apply,
            role: .task
        ) {
            SwiftCodeBlock(
                code: content.code,
                language: content.language,
                spokenLabel: "의미 단위 조각을 찾을 \(content.language) 코드"
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("읽기 렌즈")
                    .font(.subheadline.weight(.semibold))
                ForEach(
                    Array(content.lensQuestions.enumerated()),
                    id: \.offset
                ) { index, question in
                    LearningNumberedRow(
                        number: index + 1,
                        text: question,
                        accent: .cyan
                    )
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(content.selectionPrompt)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 190), spacing: 10)
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(content.elements, id: \.id) { element in
                        LearningSelectionChip(
                            title: element.text,
                            isSelected: selectedElementIDs.contains(
                                element.id
                            )
                        ) {
                            toggle(element.id)
                        }
                    }
                }
            }

            responseField(
                prompt: content.chunkNamePrompt,
                placeholder: "이 조각이 하는 일을 동사로 이름 붙이기",
                key: V1LearningActivityFieldKey.semanticChunkName
            )
            responseField(
                prompt: content.flowPrompt,
                placeholder: "선택한 요소와 다른 조각 사이의 흐름",
                key: V1LearningActivityFieldKey.semanticChunkFlow
            )
            responseField(
                prompt: content.boundaryPrompt,
                placeholder: "포함하거나 제외한 근거",
                key: V1LearningActivityFieldKey.semanticChunkBoundary
            )
            responseField(
                prompt: content.changePrompt,
                placeholder: "한 요소가 바뀌면 달라질 조각과 결과",
                key: V1LearningActivityFieldKey.semanticChunkChange
            )

            V1ActivityCriteriaView(
                title: "완료 증거",
                criteria: content.completionEvidence
            )

            V1ActivityDraftStatusView(activity: activity)
        }
    }

    private func toggle(_ id: String) {
        var selection = selectedElementIDs
        if let index = selection.firstIndex(of: id) {
            selection.remove(at: index)
        } else {
            selection.append(id)
        }
        activity.updating(
            key: V1LearningActivityFieldKey.semanticChunkSelection,
            values: selection
        )
    }

    private func responseField(
        prompt: String,
        placeholder: String,
        key: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(prompt)
                .font(.callout.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            TextField(
                placeholder,
                text: activity.textBinding(for: key),
                axis: .vertical
            )
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(prompt)
        }
    }
}

private struct LearningSelectionChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .accessibilityHidden(true)
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.callout.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? Color.accentColor.opacity(0.12)
                    : Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.accentColor.opacity(0.55)
                            : Color(nsColor: .separatorColor).opacity(0.7),
                        lineWidth: 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
    }
}
