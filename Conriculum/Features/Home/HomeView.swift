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
                    contentVersionPicker

                    if store.selectedContentVersion == .v2 {
                        v2Home
                    } else {
                        v1Home
                        knowledgeSystemCard
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
            await store.send(.v2ReloadRequested).finish()
        }
    }

    private var contentVersionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("학습 콘텐츠")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker(
                "학습 콘텐츠 버전",
                selection: Binding(
                    get: { store.selectedContentVersion },
                    set: { store.send(.contentVersionSelected($0)) }
                )
            ) {
                ForEach(ContentVersion.allCases, id: \.self) { version in
                    Text(version.title).tag(version)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var v1Home: some View {
        if let snapshot = store.snapshot {
            stageHeader(snapshot.stage)
            previewDisclosure(for: snapshot.source)
            chapterCard(snapshot.chapter)
            chapterLibrary(snapshot.availableChapters)

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

    @ViewBuilder
    private var v2Home: some View {
        if let manifest = store.v2Manifest {
            VStack(alignment: .leading, spacing: 10) {
                Text("CONRICULUM · VER.2")
                    .font(.caption.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Text(manifest.title)
                    .font(.largeTitle.bold())
                    .accessibilityHeading(.h1)
                Text("코드를 게임처럼 알아보고, 의미 단위와 실행 흐름으로 읽는 독립형 과정입니다.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if let resumeChapter = v2ResumeChapter(in: manifest) {
                v2ResumeCard(resumeChapter, manifest: manifest)
            }

            V2HomeStagePager(
                manifest: manifest,
                progress: store.v2Progress,
                selectedStageID: store.selectedV2StageID,
                onStageSelected: { store.send(.v2StageSelected($0)) },
                onChapterSelected: { store.send(.v2ChapterSelected($0)) }
            )
        } else if let message = store.v2LoadErrorMessage {
            ContentUnavailableView {
                Label("ver.2 콘텐츠를 불러오지 못했습니다", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("다시 불러오기") { store.send(.v2ReloadRequested) }
                    .buttonStyle(.borderedProminent)
                Button("ver.1 기존 과정 보기") {
                    store.send(.contentVersionSelected(.v1))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 360)
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("ver.2 학습 지도를 불러오는 중입니다.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 360)
        }
    }

    private func v2ResumeChapter(in manifest: V2ContentManifest) -> V2Chapter? {
        if let pageID = store.v2Progress.lastVisitedPageID,
           let chapter = manifest.chapters.first(where: {
               $0.pages.contains { $0.id == pageID }
           }) {
            return chapter
        }
        return manifest.stages
            .sorted { $0.order < $1.order }
            .first?.chapters
            .sorted { $0.order < $1.order }
            .first
    }

    private func v2ResumeCard(
        _ chapter: V2Chapter,
        manifest: V2ContentManifest
    ) -> some View {
        let pageID = store.v2Progress.lastVisitedPageID.flatMap { pageID in
            chapter.pages.contains { $0.id == pageID } ? pageID : nil
        } ?? chapter.firstPageID
        let page = pageID.flatMap { manifest.pageReference(id: $0) }

        return VStack(alignment: .leading, spacing: 16) {
            Label(
                store.v2Progress.lastVisitedPageID == nil ? "여기서 시작해 보세요" : "이어서 학습하기",
                systemImage: "play.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(.tint)

            Text(chapter.title)
                .font(.title2.bold())
            if let page {
                VStack(alignment: .leading, spacing: 4) {
                    Text(page.title).font(.headline)
                    Text(page.goal)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Button(store.v2Progress.lastVisitedPageID == nil ? "학습 시작" : "이어보기") {
                store.send(.v2ChapterSelected(chapter.id))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
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
            Label(chapter.resumePageID == nil ? "여기서 시작해 보세요" : "이어서 학습하기", systemImage: "play.circle.fill")
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

    private var knowledgeSystemCard: some View {
        Button {
            store.send(.knowledgeSystemButtonTapped)
        } label: {
            HStack(alignment: .center, spacing: 18) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 48, height: 48)
                    .background(
                        Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text("지식 체계 둘러보기")
                        .font(.title3.weight(.semibold))
                    Text("배운 지식을 다시 읽고, 선택한 지식과 연결되는 개념을 책장에서 확인합니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityHint("지식 체계 탐색 화면을 엽니다.")
    }

    @ViewBuilder
    private func learningSummary(_ snapshot: HomeSnapshot) -> some View {
        if snapshot.lastActivity != nil || !snapshot.knowledgeChanges.confirmed.isEmpty
            || !snapshot.knowledgeChanges.pending.isEmpty {
            DisclosureGroup("이 챕터에 남긴 학습 기록") {
                VStack(alignment: .leading, spacing: 18) {
                    if snapshot.lastActivity != nil {
                        lastActivityPanel(snapshot.lastActivity)
                    }
                    if !snapshot.knowledgeChanges.confirmed.isEmpty || !snapshot.knowledgeChanges.pending.isEmpty {
                        knowledgeChangePanel(
                            snapshot.knowledgeChanges,
                            emptyMessage: snapshot.knowledgeChangesEmptyStateMessage
                        )
                    }
                }.padding(.top, 12)
            }
        }
        if snapshot.evidence.contains(where: { $0.count > 0 }) {
            evidenceSection(snapshot.evidence.filter { $0.count > 0 })
        }
    }

    private func chapterLibrary(_ chapters: [HomeSnapshot.ChapterCard]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("챕터 선택").font(.title3.weight(.semibold))
                .accessibilityHeading(.h2)
            Text("처음 읽거나, 이전 챕터로 돌아가 확인할 수 있습니다.")
                .font(.callout).foregroundStyle(.secondary)
            ForEach(chapters, id: \.chapterID) { chapter in
                Button {
                    store.send(.chapterSelected(chapter.chapterID))
                } label: {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(chapter.title).font(.headline)
                            Text(chapter.lastPage.map(lastPageLabel) ?? "학습 지도부터 시작")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Text(chapter.resumePageID == nil ? "시작하기" : "이어보기")
                        Image(systemName: "chevron.right")
                    }
                    .padding(18).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            }
        }
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
