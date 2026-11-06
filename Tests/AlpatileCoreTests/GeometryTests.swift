import Testing
import CoreGraphics
@testable import AlpatileCore

struct GeometryTests {
    @Test func isNearlyEqual() {
        let r1 = CGRect(x: 100.0, y: 100.0, width: 500.0, height: 400.0)
        let r2 = CGRect(x: 100.4, y: 99.8, width: 500.2, height: 399.7)
        let r3 = CGRect(x: 102.0, y: 100.0, width: 500.0, height: 400.0)

        #expect(r1.isNearlyEqual(to: r2, tolerance: 1.0))
        #expect(!r1.isNearlyEqual(to: r3, tolerance: 1.0))
    }

    @Test func verticalSplitWithoutGap() {
        let r = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let (left, right) = r.split(type: .vertical, ratio: 0.5, gap: 0)

        #expect(left == CGRect(x: 0, y: 0, width: 500, height: 800))
        #expect(right == CGRect(x: 500, y: 0, width: 500, height: 800))
    }

    @Test func verticalSplitWithGap() {
        let r = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let (left, right) = r.split(type: .vertical, ratio: 0.5, gap: 10)

        #expect(left == CGRect(x: 0, y: 0, width: 495, height: 800))
        #expect(right == CGRect(x: 505, y: 0, width: 495, height: 800))
    }

    @Test func horizontalSplitWithGap() {
        let r = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let (top, bottom) = r.split(type: .horizontal, ratio: 0.5, gap: 20)

        #expect(top == CGRect(x: 0, y: 0, width: 1000, height: 390))
        #expect(bottom == CGRect(x: 0, y: 410, width: 1000, height: 390))
    }

    @Test func cocoaToAXCoordinateConversion() {
        let cocoaFrame = CGRect(x: 0, y: 100, width: 1920, height: 900)
        let axFrame = CGRect.convertCocoaVisibleFrameToAX(cocoaFrame: cocoaFrame, primaryScreenHeight: 1080)

        #expect(axFrame.origin.x == 0)
        #expect(axFrame.origin.y == 80)
        #expect(axFrame.width == 1920)
        #expect(axFrame.height == 900)
    }

    @Test func findNeighborInAllDirections() {
        let westRect = CGRect(x: 0, y: 0, width: 400, height: 800)
        let centerRect = CGRect(x: 400, y: 200, width: 400, height: 400)
        let eastRect = CGRect(x: 800, y: 0, width: 400, height: 800)
        let northRect = CGRect(x: 400, y: 0, width: 400, height: 200)
        let southRect = CGRect(x: 400, y: 600, width: 400, height: 200)

        let candidates: [(id: WindowID, rect: CGRect)] = [
            (id: 1, rect: westRect),
            (id: 2, rect: eastRect),
            (id: 3, rect: northRect),
            (id: 4, rect: southRect)
        ]

        #expect(GeometryHelper.findNeighbor(from: centerRect, among: candidates, direction: .west) == 1)
        #expect(GeometryHelper.findNeighbor(from: centerRect, among: candidates, direction: .east) == 2)
        #expect(GeometryHelper.findNeighbor(from: centerRect, among: candidates, direction: .north) == 3)
        #expect(GeometryHelper.findNeighbor(from: centerRect, among: candidates, direction: .south) == 4)
    }
}
