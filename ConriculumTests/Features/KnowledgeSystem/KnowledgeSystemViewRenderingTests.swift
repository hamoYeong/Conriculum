import AppKit
import ComposableArchitecture
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
@Suite(.serialized)
struct KnowledgeSystemViewRenderingTests {
    @Test
    func bookshelfUsesThreeThenTwoColumnsAndGivesDetailTheRemainder() {
        #expect(KnowledgeBookshelfLayout.width(forColumns: 3) == 792)
        #expect(KnowledgeBookshelfLayout.width(forColumns: 2) == 538)
        for (width, columns) in [(1800.0, 3), (1103.0, 3), (1102.0, 2), (849.0, 2), (848.0, 1), (595.0, 1)] {
            let layout = KnowledgeBookshelfLayout.resolve(availableWidth: width, hasDetail: true)
            #expect(layout.columns == columns)
            #expect(layout.showsSideDetail)
            #expect(width - layout.shelfWidth - KnowledgeBookshelfLayout.dividerWidth >= KnowledgeBookshelfLayout.minimumDetailWidth)
        }
        #expect(!KnowledgeBookshelfLayout.resolve(availableWidth: 594, hasDetail: true).showsSideDetail)
        #expect(KnowledgeBookshelfLayout.resolve(availableWidth: 1800, hasDetail: false).shelfWidth == 1800)
    }

    @Test
    func actualShelfWidthFollowsColumnPolicyWhileWindowResizes() async throws {
        var state = KnowledgeSystemFeature.State(snapshot: try makeSnapshot())
        state.selectedConceptIDs = ["concept-type"]
        let host = NSHostingView(rootView: KnowledgeSystemView(store: Store(initialState: state) { KnowledgeSystemFeature() }))
        host.frame = NSRect(x: 0, y: 0, width: 1600, height: 800)
        let window = NSWindow(contentRect: host.frame, styleMask: [], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        for width in [1600.0, 2000, 1400, 1100, 1000, 720, 1400] {
            window.setContentSize(NSSize(width: width, height: 800))
            window.layoutIfNeeded()
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            let splits = allSubviews(host).compactMap { $0 as? NSSplitView }
            let navigation = try #require(splits.first { $0.isVertical })
            let detailRegion = try #require(navigation.arrangedSubviews.last)
            let shelfSplit = try #require(splits.first { !$0.isVertical })
            // NavigationSplitView extends native views beneath the sidebar safe area.
            let regionWidth = detailRegion.bounds.width - detailRegion.safeAreaInsets.left - detailRegion.safeAreaInsets.right
            let shelfWidth = shelfSplit.bounds.width - shelfSplit.safeAreaInsets.left - shelfSplit.safeAreaInsets.right
            let layout = KnowledgeBookshelfLayout.resolve(availableWidth: regionWidth, hasDetail: true)
            #expect(abs(shelfWidth - layout.shelfWidth) <= 1,
                    "window \(width), region \(regionWidth), shelf \(shelfWidth), expected \(layout.shelfWidth)")
        }
    }

    @Test
    func metadataRowKeepsStatusAndAllRelationTypesAccessibleAtCardWidth() async throws {
        for status in KnowledgeSystemSnapshot.LearningStatus.allCases {
            let view = KnowledgeShelfMetadataRow(status: status, tint: .teal,
                relationKinds: Set(KnowledgeRelationKind.allCases), hasPersonalRelation: true)
                .padding(14)
                .frame(width: KnowledgeBookshelfLayout.cardWidth, height: 70)
            let image = try await render(view, size: CGSize(width: 240, height: 70))
            #expect(image.size.width == 240)
            try writeCaptureIfRequested(image, name: "metadata-\(status.rawValue)")
        }
    }

    @Test
    func openingAndClosingDetailKeepsBookshelfScrollView() async throws {
        let snapshot = try makeSnapshot()
        let store = Store(initialState: KnowledgeSystemFeature.State(snapshot: snapshot)) { KnowledgeSystemFeature() }
        let host = NSHostingView(rootView: KnowledgeSystemView(store: store))
        host.frame = NSRect(x: 0, y: 0, width: 1100, height: 720)
        let window = NSWindow(contentRect: host.frame, styleMask: [], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        window.layoutIfNeeded()
        host.layoutSubtreeIfNeeded()
        await Task.yield()
        host.layoutSubtreeIfNeeded()
        // Select the bookshelf's vertical split, not whichever sidebar currently has the longest document.
        let shelfSplit = try #require(allSubviews(host).compactMap { $0 as? NSSplitView }.first { !$0.isVertical })
        let shelfPane = try #require(shelfSplit.arrangedSubviews.first)
        let shelf = try #require(allSubviews(shelfPane).compactMap { $0 as? NSScrollView }.first)
        let event = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
            wheelCount: 1, wheel1: -240, wheel2: 0, wheel3: 0))
        shelf.scrollWheel(with: try #require(NSEvent(cgEvent: event)))
        for _ in 0..<30 where shelf.contentView.bounds.minY == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(shelf.contentView.bounds.minY > 0, "document: \(String(describing: shelf.documentView?.frame)), viewport: \(shelf.bounds)")
        for action in [KnowledgeSystemFeature.Action.conceptSelected("concept-type"), .selectionCleared] {
            store.send(action)
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            #expect(allSubviews(host).contains { $0 === shelf })
            #expect(shelf.contentView.bounds.minY > 0, "scroll offset after \(action)")
        }
    }

    private func allSubviews(_ view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + allSubviews($0) }
    }

    @Test
    func shelfDetailAndComparisonLayoutsRender() async throws {
        let snapshot = try makeSnapshot()
        let fixtures: [Fixture] = [
            Fixture(
                name: "shelf-wide",
                size: CGSize(width: 1_100, height: 760),
                selectedConceptIDs: []
            ),
            Fixture(
                name: "shelf-detail-narrow",
                size: CGSize(width: 720, height: 720),
                selectedConceptIDs: ["concept-type"]
            ),
            Fixture(
                name: "shelf-detail-minimum",
                size: CGSize(width: 720, height: 600),
                selectedConceptIDs: ["concept-type"]
            ),
            Fixture(
                name: "shelf-detail-wide",
                size: CGSize(width: 1400, height: 900),
                selectedConceptIDs: ["concept-type"]
            ),
            Fixture(
                name: "shelf-detail-extra-wide",
                size: CGSize(width: 2000, height: 900),
                selectedConceptIDs: ["concept-type"]
            ),
            Fixture(
                name: "shelf-detail-two-columns",
                size: CGSize(width: 1200, height: 900),
                selectedConceptIDs: ["concept-type"]
            ),
            Fixture(
                name: "comparison-wide",
                size: CGSize(width: 1_100, height: 760),
                selectedConceptIDs: ["concept-type", "concept-value"]
            ),
        ]

        for fixture in fixtures {
            var state = KnowledgeSystemFeature.State(snapshot: snapshot)
            state.selectedConceptIDs = fixture.selectedConceptIDs
            state.selectedCollectionID = "collection-02-values-and-types"

            let view = KnowledgeSystemView(
                store: Store(initialState: state) {
                    KnowledgeSystemFeature()
                }
            )
            .frame(width: fixture.size.width, height: fixture.size.height)

            let image = try await render(view, size: fixture.size)
            #expect(image.size == fixture.size)
            #expect(sampledColorCount(in: image) > 3)
            try writeCaptureIfRequested(image, name: fixture.name)
        }
    }

    private func makeSnapshot() throws -> KnowledgeSystemSnapshot {
        let catalog = try ContentResourceDecoder().decode(
            KnowledgeCatalog.self,
            from: .valuesAndTypes
        )
        let revision = PersonalConceptRevision(
            id: "render-revision-type",
            conceptID: "concept-type",
            personalTitle: "할 수 있는 일의 약속",
            explanation: "값의 가능한 사용을 함께 설명한다.",
            examples: [],
            previousRevisionID: nil,
            evidenceActivityID: "render-activity",
            createdAt: Date(timeIntervalSince1970: 20)
        )
        return KnowledgeSystemSnapshotComposer().compose(
            catalog: catalog,
            revisions: [revision],
            personalRelations: [],
            learnedConceptIDs: ["concept-value", "concept-type", "concept-bool", "concept-string", "concept-int"]
        )
    }

    private func render<V: View>(
        _ view: V,
        size: CGSize
    ) async throws -> NSBitmapImageRep {
        let hostingView = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        hostingView.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hostingView.frame, styleMask: [], backing: .buffered, defer: false)
        window.contentView = hostingView
        window.appearance = NSAppearance(named: .aqua)
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(150))
        window.layoutIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        let image = try #require(
            hostingView.bitmapImageRepForCachingDisplay(
                in: hostingView.bounds
            )
        )
        hostingView.cacheDisplay(in: hostingView.bounds, to: image)
        return image
    }

    private func sampledColorCount(
        in image: NSBitmapImageRep
    ) -> Int {
        let horizontalStep = max(image.pixelsWide / 24, 1)
        let verticalStep = max(image.pixelsHigh / 24, 1)
        var colors: Set<Int> = []

        for x in stride(from: 0, to: image.pixelsWide, by: horizontalStep) {
            for y in stride(from: 0, to: image.pixelsHigh, by: verticalStep) {
                guard let color = image.colorAt(x: x, y: y)?
                    .usingColorSpace(.deviceRGB)
                else { continue }

                let red = Int(color.redComponent * 15)
                let green = Int(color.greenComponent * 15)
                let blue = Int(color.blueComponent * 15)
                colors.insert((red << 8) | (green << 4) | blue)
            }
        }

        return colors.count
    }

    private func writeCaptureIfRequested(
        _ image: NSBitmapImageRep,
        name: String
    ) throws {
        let data = try #require(
            image.representation(using: .png, properties: [:])
        )
        Attachment.record(Array(data), named: "knowledge-system-\(name).png")
    }
}

private struct Fixture {
    let name: String
    let size: CGSize
    let selectedConceptIDs: [KnowledgeConceptID]
}
