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

    @Test func rotate90FourCycles() {
        let tree = BSPTree()
        tree.insert(windowId: 101)
        tree.insert(windowId: 102)

        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let initialFrames = tree.calculateFrames(bounds: bounds)

        // 1st rotation: 90 deg clockwise (Vertical -> Horizontal, no child swap)
        // 101 at top (0..400), 102 at bottom (400..800)
        tree.rotate90()
        let r1 = tree.calculateFrames(bounds: bounds)
        #expect(r1.count == 2)
        #expect(r1[0].id == 101)
        #expect(r1[0].rect == CGRect(x: 0, y: 0, width: 1000, height: 400))
        #expect(r1[1].id == 102)
        #expect(r1[1].rect == CGRect(x: 0, y: 400, width: 1000, height: 400))

        // 2nd rotation: 180 deg clockwise (Horizontal -> Vertical, child swap)
        // 102 at left (0..500), 101 at right (500..1000)
        tree.rotate90()
        let r2 = tree.calculateFrames(bounds: bounds)
        #expect(r2.count == 2)
        #expect(r2[0].id == 102)
        #expect(r2[0].rect == CGRect(x: 0, y: 0, width: 500, height: 800))
        #expect(r2[1].id == 101)
        #expect(r2[1].rect == CGRect(x: 500, y: 0, width: 500, height: 800))

        // 3rd rotation: 270 deg clockwise (Vertical -> Horizontal, no child swap)
        // 102 at top (0..400), 101 at bottom (400..800)
        tree.rotate90()
        let r3 = tree.calculateFrames(bounds: bounds)
        #expect(r3.count == 2)
        #expect(r3[0].id == 102)
        #expect(r3[0].rect == CGRect(x: 0, y: 0, width: 1000, height: 400))
        #expect(r3[1].id == 101)
        #expect(r3[1].rect == CGRect(x: 0, y: 400, width: 1000, height: 400))

        // 4th rotation: 360 deg clockwise (Horizontal -> Vertical, child swap)
        // Back to initial: 101 at left, 102 at right
        tree.rotate90()
        let r4 = tree.calculateFrames(bounds: bounds)
        #expect(r4.count == 2)
        #expect(r4[0].id == initialFrames[0].id)
        #expect(r4[0].rect == initialFrames[0].rect)
        #expect(r4[1].id == initialFrames[1].id)
        #expect(r4[1].rect == initialFrames[1].rect)
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

    @Test func threeWindowsInsertionAndRemoval() {
        let tree = BSPTree()
        tree.insert(windowId: 1)
        tree.insert(windowId: 2)
        tree.insert(windowId: 3)

        #expect(tree.allWindowIDs().count == 3)
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frames3 = tree.calculateFrames(bounds: bounds)
        #expect(frames3.count == 3)

        #expect(tree.remove(windowId: 2))
        #expect(!tree.contains(windowId: 2))
        #expect(tree.contains(windowId: 1))
        #expect(tree.contains(windowId: 3))

        let frames2 = tree.calculateFrames(bounds: bounds)
        #expect(frames2.count == 2)
    }

    @Test func emptyTreeOperations() {
        let tree = BSPTree()
        #expect(tree.isEmpty)
        #expect(tree.allWindowIDs().isEmpty)
        #expect(!tree.contains(windowId: 99))
        #expect(!tree.remove(windowId: 99))
        #expect(!tree.toggleSplit(for: 99))
        #expect(tree.warp(windowId: 99, direction: .west, bounds: .zero) == nil)

        // Should not crash
        tree.balance()
        tree.rotate90()
        #expect(tree.calculateFrames(bounds: .zero).isEmpty)
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

    @Test func balanceGivesEqualSizesToWindowsInOneRow() {
        let tree = BSPTree()
        tree.insert(windowId: 1)
        tree.insert(windowId: 2)
        tree.insert(windowId: 3, near: 2)
        // Make every split vertical (left/right): all three windows form one row.
        func makeVertical(_ node: BSPNode?) {
            guard let node, !node.isLeaf else { return }
            node.splitType = .vertical
            makeVertical(node.firstChild)
            makeVertical(node.secondChild)
        }
        makeVertical(tree.root)

        tree.balance()
        let frames = tree.calculateFrames(bounds: CGRect(x: 0, y: 0, width: 900, height: 600))
        #expect(frames.count == 3)
        for frame in frames {
            #expect(frame.rect.width == 300)
            #expect(frame.rect.height == 600)
        }
    }

    @Test func balanceEqualizesPerAxisForMixedSplits() {
        // Layout: V(1, H(2, V(3, 4))) -> windows 1, 3 and 4 share one row, so each gets a third of the width.
        let tree = BSPTree()
        tree.insert(windowId: 1)
        tree.insert(windowId: 2)
        tree.insert(windowId: 3, near: 2)
        tree.insert(windowId: 4, near: 3)
        tree.root?.ratio = 0.9
        tree.balance()
        let frames = Dictionary(uniqueKeysWithValues: tree.calculateFrames(bounds: CGRect(x: 0, y: 0, width: 900, height: 600)).map { ($0.id, $0.rect) })
        #expect(frames[1]?.width == 300)
        #expect(frames[3]?.width == 300)
        #expect(frames[4]?.width == 300)
        #expect(frames[2]?.width == 600)
        #expect(frames[2]?.height == 300)
    }

    @Test func selectTreeRestoresSavedSpaceLayout() {
        let spaceA = BSPTree()
        spaceA.insert(windowId: 1)
        spaceA.insert(windowId: 2)
        let spaceB = BSPTree()
        spaceB.insert(windowId: 10)
        spaceB.insert(windowId: 11)

        #expect(WindowEngine.selectTree(for: [1, 2], among: [spaceA, spaceB], preferring: spaceB) === spaceA)
        #expect(WindowEngine.selectTree(for: [10, 11, 12], among: [spaceA, spaceB], preferring: spaceA) === spaceB)
        // A window shared by every Space must not glue a brand new Space to an old tree.
        #expect(WindowEngine.selectTree(for: [1, 20, 21], among: [spaceA, spaceB], preferring: nil) == nil)
    }
}
