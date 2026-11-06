import Testing
import CoreGraphics
@testable import AlpatileCore

struct BSPTreeTests {
    @Test func singleWindow() {
        let tree = BSPTree()
        tree.insert(windowId: 101)

        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frames = tree.calculateFrames(bounds: bounds)

        #expect(frames.count == 1)
        #expect(frames.first?.id == 101)
        #expect(frames.first?.rect == bounds)
    }

    @Test func twoWindowsSplit() {
        let tree = BSPTree()
        tree.insert(windowId: 101)
        tree.insert(windowId: 102)

        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frames = tree.calculateFrames(bounds: bounds)

        #expect(frames.count == 2)
        #expect(frames[0].id == 101)
        #expect(frames[0].rect == CGRect(x: 0, y: 0, width: 500, height: 800))
        #expect(frames[1].id == 102)
        #expect(frames[1].rect == CGRect(x: 500, y: 0, width: 500, height: 800))
    }

    @Test func toggleSplit() {
        let tree = BSPTree()
        tree.insert(windowId: 101)
        tree.insert(windowId: 102)

        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)

        // Before toggle: vertical split
        let before = tree.calculateFrames(bounds: bounds)
        #expect(before[0].rect.width == 500)
        #expect(before[0].rect.height == 800)

        // Toggle split on window 101
        #expect(tree.toggleSplit(for: 101))

        // After toggle: horizontal split
        let after = tree.calculateFrames(bounds: bounds)
        #expect(after[0].rect.width == 1000)
        #expect(after[0].rect.height == 400)
        #expect(after[1].rect.width == 1000)
        #expect(after[1].rect.height == 400)
    }

    @Test func rotate90() {
        let tree = BSPTree()
        tree.insert(windowId: 101)
        tree.insert(windowId: 102)

        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)

        tree.rotate90()
        let frames = tree.calculateFrames(bounds: bounds)

        #expect(frames.count == 2)
        #expect(frames[0].id == 102)
        #expect(frames[0].rect == CGRect(x: 0, y: 0, width: 1000, height: 400))
        #expect(frames[1].id == 101)
        #expect(frames[1].rect == CGRect(x: 0, y: 400, width: 1000, height: 400))
    }

    @Test func warpFourDirections() {
        let tree = BSPTree()
        tree.insert(windowId: 1)
        tree.insert(windowId: 2)

        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)

        // Warp window 1 east
        let warpedId = tree.warp(windowId: 1, direction: .east, bounds: bounds)
        #expect(warpedId == 2)

        let afterEast = tree.calculateFrames(bounds: bounds)
        #expect(afterEast[0].id == 2)
        #expect(afterEast[1].id == 1)

        // Warp window 1 west
        let warpedWest = tree.warp(windowId: 1, direction: .west, bounds: bounds)
        #expect(warpedWest == 2)

        let afterWest = tree.calculateFrames(bounds: bounds)
        #expect(afterWest[0].id == 1)
        #expect(afterWest[1].id == 2)
    }

    @Test func removeWindow() {
        let tree = BSPTree()
        tree.insert(windowId: 1)
        tree.insert(windowId: 2)
        tree.insert(windowId: 3)

        #expect(tree.remove(windowId: 2))
        #expect(!tree.contains(windowId: 2))
        #expect(tree.contains(windowId: 1))
        #expect(tree.contains(windowId: 3))

        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frames = tree.calculateFrames(bounds: bounds)
        #expect(frames.count == 2)
    }

    @Test func balance() {
        let tree = BSPTree()
        tree.insert(windowId: 1)
        tree.insert(windowId: 2)

        tree.root?.ratio = 0.8
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let framesBefore = tree.calculateFrames(bounds: bounds)
        #expect(framesBefore[0].rect.width == 800)

        tree.balance()
        let framesAfter = tree.calculateFrames(bounds: bounds)
        #expect(framesAfter[0].rect.width == 500)
    }
}
