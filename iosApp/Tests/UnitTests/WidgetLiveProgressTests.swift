@testable import ITMOWidgets
import SwiftUI
import UIKit
import XCTest

/// The gallery's frozen clock uses a different, value-based ProgressView. Exercise the date-relative view too,
/// without a custom spinner style from the snapshot harness. These are hosted render tests, not WidgetKit archives.
@MainActor
final class WidgetLiveProgressTests: XCTestCase {
    func testLiveBarRendersBeforeDuringAndAfterTheLesson() async throws {
        try await assertLiveProgress(ring: false, size: CGSize(width: 140, height: 30))
    }

    func testLiveRingRendersBeforeDuringAndAfterTheLesson() async throws {
        try await assertLiveProgress(ring: true, size: CGSize(width: 60, height: 60))
    }

    private func assertLiveProgress(ring: Bool, size: CGSize) async throws {
        let blank = try await render(Color.black, size: size)
        let now = Date()
        let intervals: [(String, TimeInterval, TimeInterval)] = [
            ("before", 600, 6_000),
            ("during", -1_440, 3_960),
            ("after", -6_000, -600),
        ]
        for (state, start, end) in intervals {
            let progress = WidgetLessonProgress(
                since: now.addingTimeInterval(start), until: now.addingTimeInterval(end), clock: .live, ring: ring
            )
            let image = try await render(progress, size: size)
            XCTAssertNotEqual(image, blank, "The live progress is empty \(state) the lesson (ring: \(ring))")
        }
    }

    private func render<V: View>(_ view: V, size: CGSize) async throws -> Data {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let root = view
            .tint(.white)
            .environment(\.colorScheme, .dark)
            .frame(width: size.width, height: size.height)
            .background(Color.black)
        let host = UIHostingController(rootView: root)
        host.safeAreaRegions = []
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        window.windowLevel = .alert + 1
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            window.windowScene = nil
            previousKeyWindow?.makeKey()
        }
        // Let SwiftUI mount the live system progress view, without comparing timer-dependent pixels to a baseline.
        try await Task.sleep(for: .milliseconds(100))
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        var drawn = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            drawn = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertTrue(drawn, "The hosted progress view could not be rendered")
        return try XCTUnwrap(image.pngData())
    }
}
