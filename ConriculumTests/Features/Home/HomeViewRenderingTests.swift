import AppKit
import ComposableArchitecture
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct HomeViewRenderingTests {
    @Test
    func emptyAndPopulatedPreviewsRenderAtAStandardWindowSize() throws {
        let fixtures: [(name: String, snapshot: HomeSnapshot)] = [
            ("empty", HomePreviewFixtures.empty),
            ("populated", HomePreviewFixtures.mock),
        ]

        for fixture in fixtures {
            let view = HomeView(
                store: Store(
                    initialState: HomeFeature.State(
                        snapshot: fixture.snapshot,
                        usesSnapshotAsPlaceholder: true
                    )
                ) {
                    HomeFeature()
                }
            )
            .frame(width: 960, height: 900)

            let hostingView = NSHostingView(rootView: view)
            hostingView.frame = NSRect(x: 0, y: 0, width: 960, height: 900)
            hostingView.layoutSubtreeIfNeeded()
            let image = try #require(
                hostingView.bitmapImageRepForCachingDisplay(
                    in: hostingView.bounds
                )
            )
            hostingView.cacheDisplay(in: hostingView.bounds, to: image)

            #expect(image.size.width == 960)
            #expect(image.size.height == 900)
            #expect(sampledColorCount(in: image) > 2)

            try writeCaptureIfRequested(
                image,
                name: fixture.name
            )
        }
    }

    private func writeCaptureIfRequested(
        _ image: NSBitmapImageRep,
        name: String
    ) throws {
        guard let directory = ProcessInfo.processInfo.environment[
            "CONRICULUM_HOME_CAPTURE_DIRECTORY"
        ] else { return }

        let data = try #require(
            image.representation(using: .png, properties: [:])
        )
        try data.write(
            to: URL(fileURLWithPath: directory)
                .appendingPathComponent("home-\(name).png")
        )
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
}
