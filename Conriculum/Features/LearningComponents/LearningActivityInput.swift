import SwiftUI

struct LearningActivityInput {
    let activityID: LearningActivityID
    let fields: [ActivityResponseField]
    let onFieldsChanged: (
        _ activityID: LearningActivityID,
        _ fields: [ActivityResponseField]
    ) -> Void

    init(
        activityID: LearningActivityID,
        fields: [ActivityResponseField],
        onFieldsChanged: @escaping (
            _ activityID: LearningActivityID,
            _ fields: [ActivityResponseField]
        ) -> Void
    ) {
        self.activityID = activityID
        self.fields = fields
        self.onFieldsChanged = onFieldsChanged
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
        var updatedFields = fields
        if let index = updatedFields.firstIndex(where: { $0.key == key }) {
            updatedFields[index] = ActivityResponseField(
                key: key,
                values: values
            )
        } else {
            updatedFields.append(ActivityResponseField(key: key, values: values))
        }
        onFieldsChanged(activityID, updatedFields)
    }

    func textBinding(for key: String) -> Binding<String> {
        Binding(
            get: { value(for: key) },
            set: { updating(key: key, values: [$0]) }
        )
    }
}

enum LearningActivityFieldKey {
    static let reason = "reason"
    static let response = "response"
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
