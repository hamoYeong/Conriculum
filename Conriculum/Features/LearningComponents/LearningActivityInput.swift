import Foundation
import SwiftUI

enum ActivityDraftSaveState: Equatable, Sendable {
    case idle
    case pending
    case saving
    case saved(Date)
    case validationError(String)
    case persistenceError(String)

    var accessibilityDescription: String? {
        switch self {
        case .idle:
            nil
        case .pending:
            "활동 응답 변경 사항 저장 대기 중"
        case .saving:
            "활동 응답 저장 중"
        case .saved:
            "활동 응답 저장됨"
        case let .validationError(message):
            "입력을 확인해 주세요. \(message)"
        case let .persistenceError(message):
            "저장하지 못했습니다. \(message)"
        }
    }
}

struct LearningActivityInput {
    let activityID: LearningActivityID
    let fields: [ActivityResponseField]
    let onFieldsChanged: (
        _ activityID: LearningActivityID,
        _ fields: [ActivityResponseField]
    ) -> Void
    let saveState: ActivityDraftSaveState
    let onRetry: (_ activityID: LearningActivityID) -> Void

    init(
        activityID: LearningActivityID,
        fields: [ActivityResponseField],
        onFieldsChanged: @escaping (
            _ activityID: LearningActivityID,
            _ fields: [ActivityResponseField]
        ) -> Void,
        saveState: ActivityDraftSaveState = .idle,
        onRetry: @escaping (_ activityID: LearningActivityID) -> Void = { _ in }
    ) {
        self.activityID = activityID
        self.fields = fields
        self.onFieldsChanged = onFieldsChanged
        self.saveState = saveState
        self.onRetry = onRetry
    }

    func values(for key: String) -> [String] {
        fields.first { $0.key == key }?.values ?? []
    }

    func value(for key: String) -> String {
        values(for: key).first ?? ""
    }

    func updating(
        key: String,
        values: [String]
    ) {
        updating(valuesByKey: [key: values])
    }

    func updating(
        valuesByKey: [String: [String]]
    ) {
        var updatedFields = fields
        for key in valuesByKey.keys.sorted() {
            guard let values = valuesByKey[key] else { continue }
            if let index = updatedFields.firstIndex(where: { $0.key == key }) {
                updatedFields[index] = ActivityResponseField(
                    key: key,
                    values: values
                )
            } else {
                updatedFields.append(ActivityResponseField(
                    key: key,
                    values: values
                ))
            }
        }
        onFieldsChanged(activityID, updatedFields)
    }

    func textBinding(for key: String) -> Binding<String> {
        Binding(
            get: { value(for: key) },
            set: { updating(key: key, values: [$0]) }
        )
    }

    func textBinding(
        for key: String,
        default defaultValue: String
    ) -> Binding<String> {
        Binding(
            get: {
                let storedValue = value(for: key)
                return storedValue.isEmpty ? defaultValue : storedValue
            },
            set: { updating(key: key, values: [$0]) }
        )
    }
}

struct ActivityDraftStatusView: View {
    let activity: LearningActivityInput

    @ViewBuilder
    var body: some View {
        switch activity.saveState {
        case .idle:
            EmptyView()

        case .pending:
            statusLabel(
                title: "변경 사항 저장 대기 중",
                systemImage: "clock",
                color: .secondary
            )

        case .saving:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("저장 중")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                activity.saveState.accessibilityDescription
                    ?? "활동 응답 저장 중"
            )

        case let .saved(date):
            statusLabel(
                title: "저장됨",
                systemImage: "checkmark.circle.fill",
                color: .green
            )
            .accessibilityValue(
                date.formatted(date: .omitted, time: .shortened)
            )

        case let .validationError(message):
            errorStatus(
                title: "입력을 확인해 주세요",
                message: message,
                allowsRetry: false
            )

        case let .persistenceError(message):
            errorStatus(
                title: "저장하지 못했습니다",
                message: message,
                allowsRetry: true
            )
        }
    }

    private func statusLabel(
        title: String,
        systemImage: String,
        color: Color
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .accessibilityLabel(
                activity.saveState.accessibilityDescription
                    ?? "활동 응답 \(title)"
            )
    }

    private func errorStatus(
        title: String,
        message: String,
        allowsRetry: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                    Text(message)
                        .font(.caption)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)

            if allowsRetry {
                Button("다시 저장") {
                    activity.onRetry(activity.activityID)
                }
                .controlSize(.small)
                .accessibilityHint("입력은 유지한 채 저장을 다시 시도합니다.")
            }
        }
        .padding(10)
        .background(
            Color.red.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            activity.saveState.accessibilityDescription
                ?? "\(title). \(message)"
        )
    }
}

enum LearningActivityFieldKey {
    static let reason = "reason"
    static let response = "response"
    static let completionAssessment = "completionAssessment"
    static let personalExpression = "personalExpression"
    static let relationStatement = "relationStatement"
    static let relationSourceConceptID = "relationSourceConceptID"
    static let relationTargetConceptID = "relationTargetConceptID"
    static func card(_ cardID: String) -> String {
        "card.\(cardID)"
    }

    static func match(_ itemID: String) -> String {
        "match.\(itemID)"
    }

    static func choice(_ questionID: String) -> String {
        "choice.\(questionID)"
    }

    static func blank(_ blankID: String) -> String {
        "blank.\(blankID)"
    }

    static func codeLine(_ index: Int) -> String {
        "codeLine.\(index)"
    }

    static func recall(_ index: Int) -> String {
        "recall.\(index)"
    }
}

struct ActivityCriteriaView: View {
    let title: String
    let criteria: [String]
    let systemImage: String
    let accent: Color

    init(
        title: String,
        criteria: [String],
        systemImage: String = "checkmark.circle",
        accent: Color = .green
    ) {
        self.title = title
        self.criteria = criteria
        self.systemImage = systemImage
        self.accent = accent
    }

    var body: some View {
        if !criteria.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .accessibilityHeading(.h3)

                ForEach(Array(criteria.enumerated()), id: \.offset) {
                    _,
                    criterion in
                    Label(criterion, systemImage: "circle.fill")
                        .labelStyle(ActivityCriterionLabelStyle())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                accent.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .accessibilityElement(children: .contain)
        }
    }
}

private struct ActivityCriterionLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            configuration.icon
                .font(.system(size: 5))
                .accessibilityHidden(true)
            configuration.title
                .foregroundStyle(.secondary)
        }
    }
}
