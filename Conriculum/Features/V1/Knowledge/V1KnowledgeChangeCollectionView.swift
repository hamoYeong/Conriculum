import SwiftUI

struct V1KnowledgeChangeCollectionView: View {
    let collection: V1KnowledgeChangeCollection
    let confirmedEmptyMessage: String
    var onConceptSelected: ((KnowledgeConceptID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            changeSectionTitle(
                "확인해 저장한 변화",
                systemImage: "checkmark.seal"
            )

            if collection.confirmed.isEmpty {
                neutralState(
                    message: confirmedEmptyMessage,
                    systemImage: "tray"
                )
            } else {
                confirmedRows
            }

            Divider()

            changeSectionTitle(
                "확인 전 후보",
                systemImage: "text.badge.star"
            )

            if collection.pending.isEmpty {
                neutralState(
                    message: "확인 전 후보가 없습니다. 활동 답안은 그대로 유지됩니다.",
                    systemImage: "text.badge.checkmark"
                )
            } else {
                pendingRows
            }
        }
    }

    private var confirmedRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(collection.confirmed.indices, id: \.self) { index in
                if index > collection.confirmed.startIndex {
                    Divider()
                        .padding(.leading, 18)
                }

                confirmedRow(collection.confirmed[index])
                    .padding(.vertical, 6)
            }
        }
    }

    private var pendingRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(collection.pending.indices, id: \.self) { index in
                if index > collection.pending.startIndex {
                    Divider()
                        .padding(.leading, 18)
                }

                pendingRow(collection.pending[index])
                    .padding(.vertical, 6)
            }
        }
    }

    private func changeSectionTitle(
        _ title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityHeading(.h3)
    }

    @ViewBuilder
    private func confirmedRow(
        _ change: V1KnowledgeChangeCollection.Confirmed
    ) -> some View {
        switch change {
        case let .revision(revision):
            selectableRow(conceptID: revision.conceptID) {
                revisionContent(revision)
            }

        case let .relation(relation):
            changeRow {
                relationContent(relation)
            }
        }
    }

    @ViewBuilder
    private func selectableRow<Content: View>(
        conceptID: KnowledgeConceptID,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if let onConceptSelected {
            Button {
                onConceptSelected(conceptID)
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    changeRow(content: content)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("개념 상세에서 자세히 봅니다.")
        } else {
            changeRow(content: content)
        }
    }

    private func changeRow<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func revisionContent(
        _ revision: V1KnowledgeChangeCollection.Revision
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(revision.conceptTitle, systemImage: "person.text.rectangle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)

                Spacer(minLength: 8)

                Text("나의 표현")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if let personalTitle = revision.personalTitle,
               personalTitle.isEmpty == false
            {
                Text(personalTitle)
                    .font(.callout.weight(.semibold))
            }

            Text(revision.explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Label(
                    "예시 \(revision.exampleCount)개",
                    systemImage: "square.stack.3d.up"
                )
                timestamp(revision.modifiedAt)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private func relationContent(
        _ relation: V1KnowledgeChangeCollection.Relation
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("\(relation.sourceConceptTitle) → \(relation.targetConceptTitle)",
                      systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)

                Spacer(minLength: 8)

                Text("나의 연결")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(relation.statement)
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)

            if relation.reason.isEmpty == false {
                Text(relation.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            timestamp(relation.modifiedAt)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }

    private func pendingRow(
        _ candidate: V1KnowledgeChangeCollection.Pending
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(Color.orange.opacity(0.65))
                .frame(width: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label(
                        candidate.targetConceptTitle,
                        systemImage: "text.badge.star"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)

                    Spacer(minLength: 8)

                    Text("확인 전")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Color.orange.opacity(0.10),
                            in: Capsule()
                        )
                }

                Text(candidate.draft)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if candidate.connectedConceptTitles.isEmpty == false {
                    Label(
                        candidate.connectedConceptTitles.joined(
                            separator: " · "
                        ),
                        systemImage: "link"
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func neutralState(
        message: String,
        systemImage: String
    ) -> some View {
        Label {
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func timestamp(_ date: Date) -> some View {
        Label(
            date.formatted(date: .abbreviated, time: .omitted),
            systemImage: "calendar"
        )
    }
}
