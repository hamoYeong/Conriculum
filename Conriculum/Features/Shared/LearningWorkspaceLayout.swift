import AppKit
import SwiftUI

/// 학습 화면의 세 패널 너비 규칙을 적용하는 브리지.
struct LearningWorkspacePanelSizing: NSViewRepresentable {
    struct Configuration: Equatable {
        var showsSidebar: Bool
        var showsInspector: Bool
        var availableWidth: CGFloat
    }

    var configuration: Configuration

    func makeNSView(context: Context) -> SizingView { SizingView() }

    func updateNSView(_ nsView: SizingView, context: Context) {
        nsView.configuration = configuration
        nsView.scheduleSizing()
    }

    final class SizingView: NSView {
        var configuration: Configuration? {
            didSet {
                if configuration != oldValue { appliedConfiguration = nil }
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
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.sizingIsScheduled = false
                self.applySizing()
            }
        }

        private func applySizing() {
            guard let configuration, configuration != appliedConfiguration else { return }
            var ancestor = superview
            while let view = ancestor, !(view is NSSplitView) { ancestor = view.superview }
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
    var hidesKnowledgeContextFromAccessibility: Bool { self == .hidden }

    var navigationSplitViewVisibility: NavigationSplitViewVisibility {
        switch self {
        case .automatic: .automatic
        case .visible: .all
        case .hidden: .detailOnly
        }
    }

    init(visibility: NavigationSplitViewVisibility) {
        if visibility == .automatic { self = .automatic }
        else if visibility == .all { self = .visible }
        else if visibility == .detailOnly { self = .hidden }
        else { self = .automatic }
    }
}
