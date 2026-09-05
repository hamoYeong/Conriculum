import AppKit
import ComposableArchitecture
import SwiftUI

struct LearningWorkspaceView: View {
    let store: StoreOf<LearningWorkspaceFeature>

    var body: some View {
        GeometryReader { geometry in
            let layout = LearningWorkspacePanelLayout.resolve(
                availableWidth: geometry.size.width,
                inspectorIsVisible: inspectorIsVisible,
                sidebarIsHidden: sidebarIsHidden
            )
            let showsSidebar = !sidebarIsHidden && layout != .learningAndInspector
            workspaceContent(
                showsSidebar: showsSidebar,
                availableWidth: geometry.size.width
            )
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        store.send(.homeButtonTapped)
                    } label: {
                        Label("학습 홈", systemImage: "house")
                    }
                    .help("학습 홈으로 돌아가기")
                    .accessibilityHint("현재 학습 위치를 저장한 채 학습 홈으로 돌아갑니다.")

                    Button {
                        toggleSidebar(
                            isVisible: showsSidebar,
                            availableWidth: geometry.size.width
                        )
                    } label: {
                        Label(
                            showsSidebar ? "학습 문맥 숨기기" : "학습 문맥 보기",
                            systemImage: "sidebar.left"
                        )
                    }
                    .help(showsSidebar
                        ? "왼쪽 학습 문맥을 숨깁니다."
                        : "학습 문맥을 표시합니다. 좁은 창에서는 개념 상세와 번갈아 봅니다.")
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        toggleFocusModePreservingFirstResponder()
                    } label: {
                        Label(
                            store.isFocusModeEnabled
                                ? "집중 모드 끄기"
                                : "집중 모드 켜기",
                            systemImage: store.isFocusModeEnabled
                                ? "viewfinder.circle.fill"
                                : "viewfinder"
                        )
                    }
                    .help(
                        store.isFocusModeEnabled
                            ? "집중 모드를 끝내고 이전 패널 표시 상태를 복원합니다."
                            : "지식 문맥과 개념 상세를 숨기고 학습 내용에 집중합니다."
                    )
                    .accessibilityValue(
                        store.isFocusModeEnabled ? "켜짐" : "꺼짐"
                    )
                    .focusable(false)

                    Button {
                        store.send(.inspectorVisibilityButtonTapped)
                    } label: {
                        Label(
                            inspectorIsVisible
                                ? "개념 상세 숨기기"
                                : "개념 상세 보기",
                            systemImage: "sidebar.right"
                        )
                    }
                    .help(
                        store.knowledgeContext.inspector == nil
                            ? "지식 문맥에서 개념을 먼저 선택해 주세요."
                            : inspectorIsVisible
                                ? "오른쪽 개념 상세를 숨깁니다."
                                : "선택한 개념의 상세 내용을 표시합니다."
                    )
                    .disabled(store.knowledgeContext.inspector == nil)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 560)
    }

    private func workspaceContent(showsSidebar: Bool, availableWidth: CGFloat) -> some View {
        // 본문은 항상 같은 위치에 둔다. 창 크기 변경으로 본문 트리를
        // 교체하면 ScrollView의 onAppear가 학습 위치를 초기화할 수 있다.
        HSplitView {
            if showsSidebar {
                KnowledgeContextView(
                    store: store.scope(
                        state: \.knowledgeContext,
                        action: \.knowledgeContext
                    )
                )
                .frame(minWidth: 200, idealWidth: 300, maxWidth: 300)
            }

            chapterContent
                .frame(minWidth: 380, maxWidth: .infinity)
                .background {
                    LearningWorkspacePanelSizing(
                        configuration: .init(
                            showsSidebar: showsSidebar,
                            showsInspector: inspectorIsVisible,
                            availableWidth: availableWidth
                        )
                    )
                }

            if inspectorIsVisible {
                inspectorContent
                    .frame(minWidth: 240, idealWidth: 360, maxWidth: 360)
            }
        }
    }

    private var chapterContent: some View {
        ChapterLearningView(
            store: store.scope(
                state: \.chapter,
                action: \.chapter
            )
        )
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if let inspectorStore = store.scope(
            state: \.knowledgeContext.inspector,
            action: \.knowledgeContext.inspector
        ) {
            ConceptInspectorView(store: inspectorStore)
        }
    }

    private func toggleSidebar(isVisible: Bool, availableWidth: CGFloat) {
        if isVisible {
            store.send(.sidebarModeChanged(.hidden))
        } else {
            if store.isFocusModeEnabled {
                store.send(.sidebarVisibilityButtonTapped)
            } else {
                store.send(.sidebarModeChanged(.visible))
            }
            if availableWidth < LearningWorkspacePanelLayout.threePanelMinimumWidth,
               inspectorIsVisible {
                store.send(.inspectorVisibilityButtonTapped)
            }
        }
    }

    private var sidebarIsHidden: Bool {
        store.isFocusModeEnabled || store.sidebarMode == .hidden
    }

    private var inspectorIsVisible: Bool {
        !store.isFocusModeEnabled
            && store.isInspectorPresented
            && store.knowledgeContext.inspector != nil
    }

    private func toggleFocusModePreservingFirstResponder() {
        let window = NSApp.keyWindow
        let firstResponder = window?.firstResponder
        store.send(.focusModeButtonTapped)

        guard let window, let firstResponder else { return }
        Task { @MainActor in
            await Task.yield()
            window.makeFirstResponder(firstResponder)
        }
    }
}

// HSplitView의 idealWidth는 동적으로 추가되는 패널의 너비를 보장하지 않는다.
// 본문 뷰를 유지한 채 패널 표시 상태나 창 너비가 바뀔 때 분할선을 맞춘다.
private struct LearningWorkspacePanelSizing: NSViewRepresentable {
    struct Configuration: Equatable {
        var showsSidebar: Bool
        var showsInspector: Bool
        var availableWidth: CGFloat
    }

    var configuration: Configuration

    func makeNSView(context: Context) -> SizingView {
        SizingView()
    }

    func updateNSView(_ nsView: SizingView, context: Context) {
        nsView.configuration = configuration
        nsView.scheduleSizing()
    }

    final class SizingView: NSView {
        var configuration: Configuration? {
            didSet {
                if configuration != oldValue {
                    // 중간 창 크기에서 패널 교체가 진행 중이었더라도 다시 적용한다.
                    appliedConfiguration = nil
                }
            }
        }
        private var appliedConfiguration: Configuration?
        private var sizingIsScheduled = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            scheduleSizing()
        }

        override func layout() {
            super.layout()
            scheduleSizing()
        }

        func scheduleSizing() {
            guard configuration != appliedConfiguration, !sizingIsScheduled else { return }
            sizingIsScheduled = true
            // SwiftUI의 패널 추가·삭제와 레이아웃이 끝난 뒤 적용한다.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.sizingIsScheduled = false
                self.applySizing()
            }
        }

        private func applySizing() {
            guard let configuration, configuration != appliedConfiguration else { return }
            var ancestor = superview
            while let view = ancestor, !(view is NSSplitView) {
                ancestor = view.superview
            }
            guard let splitView = ancestor as? NSSplitView else { return }
            splitView.layoutSubtreeIfNeeded()
            let panelCount = (configuration.showsSidebar ? 1 : 0)
                + (configuration.showsInspector ? 1 : 0)
            guard splitView.arrangedSubviews.count == panelCount + 1 else { return }

            appliedConfiguration = configuration
            guard panelCount > 0 else { return }

            let minimum = (configuration.showsSidebar ? 200.0 : 0)
                + (configuration.showsInspector ? 240.0 : 0)
            let expansion = (configuration.showsSidebar ? 100.0 : 0)
                + (configuration.showsInspector ? 120.0 : 0)
            let available = configuration.availableWidth - 380
                - CGFloat(panelCount) * splitView.dividerThickness
            let fraction = min(1, max(0, (available - minimum) / expansion))

            // 왼쪽을 먼저 줄여 오른쪽을 넓힐 공간을 확보한 뒤 양쪽 너비를 맞춘다.
            if configuration.showsSidebar && configuration.showsInspector {
                splitView.setPosition(200, ofDividerAt: 0)
                splitView.layoutSubtreeIfNeeded()
            }
            if configuration.showsInspector {
                let width = 240 + 120 * fraction
                splitView.setPosition(
                    splitView.bounds.width - width - splitView.dividerThickness,
                    ofDividerAt: panelCount - 1
                )
                splitView.layoutSubtreeIfNeeded()
            }
            if configuration.showsSidebar {
                splitView.setPosition(200 + 100 * fraction, ofDividerAt: 0)
            }
        }
    }
}

enum LearningWorkspacePanelLayout: Equatable {
    case navigation
    case navigationAndInspector
    case learningAndInspector

    static let threePanelMinimumWidth: CGFloat = 900

    static func resolve(
        availableWidth: CGFloat,
        inspectorIsVisible: Bool,
        sidebarIsHidden: Bool
    ) -> Self {
        guard inspectorIsVisible else { return .navigation }

        if sidebarIsHidden || availableWidth < threePanelMinimumWidth {
            return .learningAndInspector
        }

        return .navigationAndInspector
    }
}

extension WorkspaceSidebarMode {
    var hidesKnowledgeContextFromAccessibility: Bool {
        self == .hidden
    }

    var navigationSplitViewVisibility: NavigationSplitViewVisibility {
        switch self {
        case .automatic: .automatic
        case .visible: .all
        case .hidden: .detailOnly
        }
    }

    init(visibility: NavigationSplitViewVisibility) {
        if visibility == .automatic {
            self = .automatic
        } else if visibility == .all {
            self = .visible
        } else if visibility == .detailOnly {
            self = .hidden
        } else {
            self = .automatic
        }
    }
}

#Preview("학습 공간 · 넓은 창") {
    LearningWorkspaceView(
        store: Store(
            initialState: LearningWorkspaceFeature.State(
                chapterID: "chapter-02",
                pageID: "chapter-02-overview"
            )
        ) {
            LearningWorkspaceFeature()
        }
    )
    .frame(width: 1_100, height: 720)
}

#Preview("학습 공간 · 좁은 창") {
    LearningWorkspaceView(
        store: Store(
            initialState: LearningWorkspaceFeature.State(
                chapterID: "chapter-02",
                pageID: "chapter-02-overview"
            )
        ) {
            LearningWorkspaceFeature()
        }
    )
    .frame(width: 720, height: 720)
}

#Preview("학습 공간 · 집중 모드") {
    LearningWorkspaceView(
        store: Store(
            initialState: LearningWorkspaceFeature.State(
                chapterID: "chapter-02",
                pageID: "chapter-02-page-03",
                isFocusModeEnabled: true
            )
        ) {
            LearningWorkspaceFeature()
        }
    )
    .frame(width: 1_100, height: 720)
}
