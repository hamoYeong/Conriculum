import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let snapshot = store.snapshot {
                        stageHeader(snapshot.stage)
                        previewDisclosure(for: snapshot.source)
                        chapterCard(snapshot.chapter)

                        if let loadErrorMessage = store.loadErrorMessage {
                            loadErrorBanner(message: loadErrorMessage)
                        }

                        learningSummary(snapshot)
                    } else if let loadErrorMessage = store.loadErrorMessage {
                        unavailableState(message: loadErrorMessage)
                    } else {
                        loadingState
                    }
                }
                .frame(maxWidth: 1_080, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 600)
        .task {
            guard store.snapshot == nil else { return }
            await store.send(.task).finish()
        }
    }

    private func stageHeader(
        _ stage: HomeSnapshot.StageSummary
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONRICULUM")
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            Text(stage.title)
                .font(.largeTitle.weight(.bold))
                .accessibilityHeading(.h1)

            Text(stage.goal)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func previewDisclosure(for source: HomeSnapshot.Source) -> some View {
        if case let .previewFixture(disclosure) = source {
            Label(disclosure, systemImage: "eye.trianglebadge.exclamationmark")
                .font(.callout.weight(.medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.orange.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .accessibilityLabel("미리보기 알림. \(disclosure)")
        }
    }

    private func chapterCard(
        _ chapter: HomeSnapshot.ChapterCard
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("지금 이어갈 학습", systemImage: "play.circle.fill")
                .font(.headline)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 8) {
                Text(chapter.title)
                    .font(.title2.weight(.bold))
                    .accessibilityHeading(.h2)

                Text(chapter.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let lastPage = chapter.lastPage {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("마지막 학습")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(lastPageLabel(lastPage))
                            .font(.callout.weight(.medium))
                    }
                } icon: {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(.tint)
                }
                .accessibilityElement(children: .combine)
            }

            if let accessNote = chapter.accessNote {
                Label(accessNote, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button(chapter.primaryActionTitle) {
                store.send(
                    chapter.resumePageID == nil
                        ? .startButtonTapped
                        : .resumeButtonTapped
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityHint(chapter.primaryActionAccessibilityHint)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.accentColor.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.accentColor.opacity(0.24), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func learningSummary(_ snapshot: HomeSnapshot) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                lastActivityPanel(snapshot.lastActivity)
                knowledgeChangePanel(
                    snapshot.knowledgeChanges,
                    emptyMessage: snapshot.knowledgeChangesEmptyStateMessage
                )
            }
            .frame(minWidth: 760)

            VStack(spacing: 18) {
                lastActivityPanel(snapshot.lastActivity)
                knowledgeChangePanel(
                    snapshot.knowledgeChanges,
                    emptyMessage: snapshot.knowledgeChangesEmptyStateMessage
                )
            }
        }

        evidenceSection(snapshot.evidence)
    }

    private func lastActivityPanel(
        _ activity: HomeSnapshot.ActivitySummary?
    ) -> some View {
        HomePanel(title: "마지막 활동", systemImage: "clock.arrow.circlepath") {
            if let activity {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activity.pageTitle)
                        .font(.headline)

                    if let sectionTitle = activity.sectionTitle {
                        Text(sectionTitle)
                            .foregroundStyle(.secondary)
                    }

                    Label(
                        activity.occurredAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        ),
                        systemImage: "clock"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(lastActivityAccessibilityLabel(activity))
            } else {
                EmptyDashboardState(
                    systemImage: "clock.badge.questionmark",
                    message: "아직 저장된 활동이 없습니다."
                )
            }
        }
    }

    private func knowledgeChangePanel(
        _ knowledgeChanges: KnowledgeChangeCollection,
        emptyMessage: String
    ) -> some View {
        HomePanel(title: "이번 학습으로 달라진 내 지식", systemImage: "sparkles") {
            KnowledgeChangeCollectionView(
                collection: knowledgeChanges,
                confirmedEmptyMessage: emptyMessage
            )
        }
    }

    private func evidenceSection(
        _ evidence: [HomeSnapshot.EvidenceSummary]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("학습 증거")
                    .font(.title3.weight(.semibold))
                    .accessibilityHeading(.h2)
                Text("저장된 행동과 설명을 종류별로 보여줍니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(minimum: 160), spacing: 14),
                    count: 3
                ),
                spacing: 14
            ) {
                ForEach(evidence, id: \.kind) { summary in
                    EvidenceCard(summary: summary)
                }
            }
        }
    }

    private func loadErrorBanner(message: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Label(
                "최신 기록을 불러오지 못했습니다. \(message)",
                systemImage: "exclamationmark.triangle"
            )
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("다시 불러오기") {
                store.send(.reloadRequested)
            }
        }
        .font(.callout)
        .padding(14)
        .background(
            Color.red.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }

    private func unavailableState(message: String) -> some View {
        ContentUnavailableView {
            Label("학습 홈을 불러오지 못했습니다", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("다시 불러오기") {
                store.send(.reloadRequested)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("학습 기록을 불러오는 중입니다.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("학습 기록을 불러오는 중")
    }

    private func lastPageLabel(
        _ page: HomeSnapshot.PageSummary
    ) -> String {
        if let order = page.order {
            return "\(order)페이지 · \(page.title)"
        }
        return page.title
    }

    private func lastActivityAccessibilityLabel(
        _ activity: HomeSnapshot.ActivitySummary
    ) -> String {
        let section = activity.sectionTitle.map { ", \($0)" } ?? ""
        let date = activity.occurredAt.formatted(
            date: .abbreviated,
            time: .shortened
        )
        return "마지막 활동, \(activity.pageTitle)\(section), \(date)"
    }
}

private struct HomePanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .accessibilityHeading(.h2)

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct EmptyDashboardState: View {
    let systemImage: String
    let message: String

    var body: some View {
        Label {
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

private struct EvidenceCard: View {
    let summary: HomeSnapshot.EvidenceSummary

    private var presentation: HomeEvidencePresentation {
        HomeEvidencePresentation(kind: summary.kind)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label(presentation.title, systemImage: presentation.systemImage)
                    .font(.callout.weight(.medium))

                Spacer(minLength: 8)

                Text("\(summary.count)")
                    .font(.title2.monospacedDigit().weight(.semibold))
            }

            if let latestAt = summary.latestAt {
                Text("최근 \(latestAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("아직 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 94, alignment: .topLeading)
        .background(
            Color.primary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(presentation.title), \(summary.count)건")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let latestAt = summary.latestAt else { return "아직 없음" }
        return "최근 기록 \(latestAt.formatted(date: .long, time: .omitted))"
    }
}

#Preview("학습 홈 · 비어 있음") {
    HomeView(
        store: Store(
            initialState: HomeFeature.State(
                snapshot: HomePreviewFixtures.empty,
                usesSnapshotAsPlaceholder: true
            )
        ) {
            HomeFeature()
        }
    )
}

#Preview("학습 홈 · 기록 있음") {
    HomeView(
        store: Store(
            initialState: HomeFeature.State(
                snapshot: HomePreviewFixtures.mock,
                usesSnapshotAsPlaceholder: true
            )
        ) {
            HomeFeature()
        }
    )
}
