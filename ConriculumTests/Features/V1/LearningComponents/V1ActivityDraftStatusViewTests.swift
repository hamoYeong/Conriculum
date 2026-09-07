import AppKit
import Foundation
import SwiftUI
import Testing

@testable import Conriculum

@MainActor
struct V1ActivityDraftStatusViewTests {
    @Test
    func everyVisibleSaveStateRendersAtStandardAndLargeText() throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let states: [(name: String, value: V1ActivityDraftSaveState)] = [
            ("pending", .pending),
            ("saving", .saving),
            ("saved", .saved(timestamp)),
            (
                "validation-error",
                .validationError("저장할 입력이 없습니다.")
            ),
            (
                "persistence-error",
                .persistenceError("네트워크 연결을 확인해 주세요.")
            ),
        ]
        let sizes: [DynamicTypeSize] = [.large, .accessibility3]

        for state in states {
            for size in sizes {
                let image = try render(
                    saveState: state.value,
                    dynamicTypeSize: size
                )

                #expect(abs(image.size.width - 560) < 0.5)
                #expect(image.size.height > 12)
                #expect(image.size.height < 240)
                #expect(sampledColorCount(in: image) > 1)
            }
        }
    }

    private func render(
        saveState: V1ActivityDraftSaveState,
        dynamicTypeSize: DynamicTypeSize
    ) throws -> NSBitmapImageRep {
        let activity = V1LearningActivityInput(
            activityID: "status-test-activity",
            fields: [],
            onFieldsChanged: { _, _ in },
            saveState: saveState
        )
        let rootView = V1ActivityDraftStatusView(activity: activity)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .padding(16)
            .frame(width: 560)
            .background(Color(nsColor: .windowBackgroundColor))
            .fixedSize(horizontal: false, vertical: true)
        let hostingView = NSHostingView(rootView: rootView)
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: 560,
            height: max(fittingSize.height, 1)
        )
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
        let verticalStep = max(image.pixelsHigh / 12, 1)
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
