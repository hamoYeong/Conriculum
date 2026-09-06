import SwiftUI

enum V2ChapterCardStatus: Equatable {
    case completed
    case current
    case upcoming
}

struct V2ChapterStatusResolver {
    let manifest: V2ContentManifest
    let progress: V2Progress

    var currentChapterID: String? {
        let chapters = manifest.stages
            .sorted { $0.order < $1.order }
            .flatMap { $0.chapters.sorted { $0.order < $1.order } }
        if let pageID = progress.lastVisitedPageID,
           let index = chapters.firstIndex(where: {
               $0.pages.contains { $0.id == pageID }
           }),
           let nextIncomplete = chapters[index...].first(where: {
               !isCompleted($0)
           }) {
            return nextIncomplete.id
        }
        return chapters.first(where: { !isCompleted($0) })?.id
    }

    func status(for chapter: V2Chapter) -> V2ChapterCardStatus {
        if isCompleted(chapter) {
            return .completed
        }
        if chapter.id == currentChapterID {
            return .current
        }
        return .upcoming
    }

    private func isCompleted(_ chapter: V2Chapter) -> Bool {
        let pageIDs = Set(chapter.pages.map(\.id))
        return !pageIDs.isEmpty && pageIDs.isSubset(of: progress.completedPageIDs)
    }
}

struct V2HomeStagePager: View {
    let manifest: V2ContentManifest
    let progress: V2Progress
    let selectedStageID: String
    let onStageSelected: (String) -> Void
    let onChapterSelected: (String) -> Void

    private var stages: [V2Stage] {
        manifest.stages.sorted { $0.order < $1.order }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("전체 학습 지도")
                        .font(.title2.bold())
                        .accessibilityHeading(.h2)
                    Text("화살표나 좌우 스와이프로 Stage를 넘기고, 어느 챕터든 바로 열 수 있습니다.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                stageArrows
            }

            Group {
                if let selectedStage = stages.first(where: { $0.id == selectedStageID })
                    ?? stages.first {
                    stagePage(selectedStage)
                        .id(selectedStage.id)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 36)
                                .onEnded { value in
                                    guard abs(value.translation.width) > abs(value.translation.height)
                                    else { return }
                                    moveStage(by: value.translation.width < 0 ? 1 : -1)
                                }
                        )
                }
            }
            .frame(minHeight: 470)
            .accessibilityLabel("Stage 선택")
        }
    }

    private var stageArrows: some View {
        HStack(spacing: 8) {
            Button {
                moveStage(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(selectedIndex == 0)
            .accessibilityLabel("이전 Stage")

            Text("\((selectedIndex ?? 0) + 1) / \(stages.count)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 42)

            Button {
                moveStage(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(selectedIndex == nil || selectedIndex == stages.count - 1)
            .accessibilityLabel("다음 Stage")
        }
        .buttonStyle(.bordered)
    }

    private var selectedIndex: Int? {
        stages.firstIndex { $0.id == selectedStageID }
    }

    private func moveStage(by offset: Int) {
        guard let selectedIndex else { return }
        let destination = selectedIndex + offset
        guard stages.indices.contains(destination) else { return }
        withAnimation { onStageSelected(stages[destination].id) }
    }

    private func stagePage(_ stage: V2Stage) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("STAGE \(stage.order)")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.tint)
                    Text(stage.title)
                        .font(.title2.bold())
                    Text(stage.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 210), spacing: 14)],
                    alignment: .leading,
                    spacing: 14
                ) {
                    let resolver = V2ChapterStatusResolver(
                        manifest: manifest,
                        progress: progress
                    )
                    ForEach(stage.chapters.sorted(by: { $0.order < $1.order })) { chapter in
                        V2ChapterCard(
                            chapter: chapter,
                            status: resolver.status(for: chapter),
                            onSelected: { onChapterSelected(chapter.id) }
                        )
                    }
                }
            }
            .padding(22)
        }
        .background(
            Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}

private struct V2ChapterCard: View {
    let chapter: V2Chapter
    let status: V2ChapterCardStatus
    let onSelected: () -> Void

    var body: some View {
        Button(action: onSelected) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text("CHAPTER \(chapter.order)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            status == .current ? Color.accentColor : Color.secondary
                        )
                    Spacer(minLength: 6)
                    badge
                }
                Text(chapter.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(chapter.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Label("챕터 열기", systemImage: "arrow.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 178, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: status == .current ? 2 : 1)
        }
        .accessibilityHint("학습 순서와 관계없이 이 챕터를 엽니다.")
    }

    @ViewBuilder
    private var badge: some View {
        switch status {
        case .completed:
            Label("완료", systemImage: "checkmark.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.green)
        case .current:
            Label("진행 중", systemImage: "play.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tint)
        case .upcoming:
            EmptyView()
        }
    }

    private var cardBackground: Color {
        switch status {
        case .completed: Color.green.opacity(0.07)
        case .current: Color.accentColor.opacity(0.15)
        case .upcoming: Color(nsColor: .controlBackgroundColor)
        }
    }

    private var borderColor: Color {
        switch status {
        case .completed: Color.green.opacity(0.35)
        case .current: Color.accentColor.opacity(0.75)
        case .upcoming: Color.primary.opacity(0.08)
        }
    }
}
