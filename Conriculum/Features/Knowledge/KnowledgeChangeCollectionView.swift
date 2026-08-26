import SwiftUI

struct KnowledgeChangeCollectionView: View {
    let collection: KnowledgeChangeCollection
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
                ForEach(collection.confirmed) { change in
                    confirmedCard(change)
                }
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
                ForEach(collection.pending) { candidate in
                    pendingCard(candidate)
                }
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
    private func confirmedCard(
        _ change: KnowledgeChangeCollection.Confirmed
    ) -> some View {
        switch change {
        case let .revision(revision):
            selectableCard(conceptID: revision.conceptID) {
                revisionContent(revision)
            }

        case let .relation(relation):
            changeCard {
                relationContent(relation)
            }
        }
    }

    @ViewBuilder
    private func selectableCard<Content: View>(
        conceptID: KnowledgeConceptID,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if let onConceptSelected {
            Button {
                onConceptSelected(conceptID)
            } label: {
                changeCard(content: content)
            }
            .buttonStyle(.plain)
            .accessibilityHint("개념 상세에서 자세히 봅니다.")
        } else {
            changeCard(content: content)
        }
    }

    private func changeCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.purple.opacity(0.18), lineWidth: 1)
        }
    }

    private func revisionContent(
        _ revision: KnowledgeChangeCollection.Revision
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
        _ relation: KnowledgeChangeCollection.Relation
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

    private func pendingCard(
        _ candidate: KnowledgeChangeCollection.Pending
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(candidate.targetConceptTitle, systemImage: "text.badge.star")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)

                Spacer(minLength: 8)

                Text("확인 전")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.10), in: Capsule())
            }

            Text(candidate.draft)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if candidate.connectedConceptTitles.isEmpty == false {
                Label(
                    candidate.connectedConceptTitles.joined(separator: " · "),
                    systemImage: "link"
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.orange.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.orange.opacity(0.20), lineWidth: 1)
        }
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private func timestamp(_ date: Date) -> some View {
        Label(
            date.formatted(date: .abbreviated, time: .omitted),
            systemImage: "calendar"
        )
    }
}
