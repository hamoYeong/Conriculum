import ComposableArchitecture
import SwiftUI

struct PersonalRelationEditorView: View {
    let store: StoreOf<PersonalRelationEditorFeature>

    var body: some View {
        KnowledgeSection(
            title: store.originalRelation == nil
                ? "새 개인 지식 관계"
                : "개인 지식 관계 수정",
            systemImage: "point.3.connected.trianglepath.dotted",
            accent: .teal,
            presentation: .surface
        ) {
            VStack(alignment: .leading, spacing: 14) {
                conceptPickers

                VStack(alignment: .leading, spacing: 6) {
                    Text("관계 문장")
                        .font(.caption.weight(.semibold))
                    TextEditor(
                        text: Binding(
                            get: { store.statement },
                            set: { store.send(.statementChanged($0)) }
                        )
                    )
                    .frame(minHeight: 100)
                    .padding(7)
                    .background(
                        Color(nsColor: .textBackgroundColor),
                        in: RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                Color(nsColor: .separatorColor),
                                lineWidth: 1
                            )
                    }
                    .accessibilityLabel("개인 지식 관계 문장")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("연결 이유")
                        .font(.caption.weight(.semibold))
                    TextField(
                        store.reasonPrompt,
                        text: Binding(
                            get: { store.reason },
                            set: { store.send(.reasonChanged($0)) }
                        ),
                        axis: .vertical
                    )
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2 ... 5)
                    .accessibilityLabel("개인 지식 관계를 만든 이유")
                }

                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("근거 학습 활동")
                            .font(.caption.weight(.semibold))
                        Text("현재 페이지의 학습 활동과 연결됨")
                            .font(.caption)
                    }
                } icon: {
                    Image(systemName: "checkmark.seal")
                }
                .foregroundStyle(.secondary)

                if let message = store.validationMessage {
                    KnowledgeMessageBanner(
                        title: "관계 내용을 확인해 주세요",
                        message: message,
                        systemImage: "exclamationmark.triangle",
                        accent: .orange
                    )
                }

                if let message = store.persistenceErrorMessage {
                    KnowledgeMessageBanner(
                        title: "개인 지식 관계를 저장하지 못했습니다",
                        message: message,
                        systemImage: "exclamationmark.triangle",
                        accent: .red
                    )
                }

                HStack {
                    Button("관계 편집 취소") {
                        store.send(.cancelButtonTapped)
                    }
                    .keyboardShortcut(.cancelAction)
                    .disabled(store.isSaving)

                    Spacer()

                    Button {
                        store.send(.saveButtonTapped)
                    } label: {
                        if store.isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("개인 지식 관계 저장 중")
                        } else {
                            Text(store.originalRelation == nil
                                ? "관계 만들기"
                                : "관계 변경 저장")
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isSaving || !store.hasUnsavedChanges)
                    .accessibilityHint(
                        "저장 후 저장소에서 다시 읽은 관계로 지식 문맥을 갱신합니다."
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var conceptPickers: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(
                "출발 개념",
                selection: Binding(
                    get: { store.sourceConceptID },
                    set: { store.send(.sourceConceptChanged($0)) }
                )
            ) {
                ForEach(store.sourceConcepts, id: \.id) { concept in
                    Text(concept.title).tag(concept.id)
                }
            }

            HStack {
                Spacer()
                Image(systemName: "arrow.down")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Spacer()
            }

            Picker(
                "연결할 개념",
                selection: Binding(
                    get: { store.targetConceptID },
                    set: { store.send(.targetConceptChanged($0)) }
                )
            ) {
                ForEach(store.targetConcepts, id: \.id) { concept in
                    Text(concept.title).tag(concept.id)
                }
            }
        }
        .pickerStyle(.menu)
        .accessibilityElement(children: .contain)
    }

}
