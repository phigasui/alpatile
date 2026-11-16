import Testing
import CoreGraphics
@testable import AlpatileCore

struct WindowEngineTests {
    @Test func moveWindowToNextDisplay() async {
        let engine = WindowEngine(initialMode: .bsp)
        await engine.setCustomDisplayIDsProviderForTesting { [1, 2] }
        await engine.setCustomBoundsProviderForTesting { id in
            id == 1 ? CGRect(x: 0, y: 0, width: 1920, height: 1080) : CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        }

        let tree1 = BSPTree()
        tree1.insert(windowId: 100)
        tree1.insert(windowId: 101)

        let tree2 = BSPTree()
        tree2.insert(windowId: 200)

        await engine.setDisplayLayoutsForTesting(displayID: 1, tree: tree1)
        await engine.setDisplayLayoutsForTesting(displayID: 2, tree: tree2)

        let result = await engine.execute(command: .windowDisplay(.next))
        #expect(result == "OK moved window 100 to display 2")
        #expect(!tree1.contains(windowId: 100))
        #expect(tree1.contains(windowId: 101))
        #expect(tree2.contains(windowId: 100))
        #expect(tree2.contains(windowId: 200))
    }

    @Test func moveWindowToPrevDisplayWrapsAround() async {
        let engine = WindowEngine(initialMode: .bsp)
        await engine.setCustomDisplayIDsProviderForTesting { [1, 2, 3] }

        let tree1 = BSPTree()
        tree1.insert(windowId: 100)
        let tree2 = BSPTree()
        let tree3 = BSPTree()

        await engine.setDisplayLayoutsForTesting(displayID: 1, tree: tree1)
        await engine.setDisplayLayoutsForTesting(displayID: 2, tree: tree2)
        await engine.setDisplayLayoutsForTesting(displayID: 3, tree: tree3)

        // Moving prev from display 1 should wrap around to display 3
        let result = await engine.execute(command: .windowDisplay(.prev))
        #expect(result == "OK moved window 100 to display 3")
        #expect(!tree1.contains(windowId: 100))
        #expect(tree3.contains(windowId: 100))
    }

    @Test func singleDisplayReturnsError() async {
        let engine = WindowEngine(initialMode: .bsp)
        await engine.setCustomDisplayIDsProviderForTesting { [1] }

        let tree1 = BSPTree()
        tree1.insert(windowId: 100)
        await engine.setDisplayLayoutsForTesting(displayID: 1, tree: tree1)

        let result = await engine.execute(command: .windowDisplay(.next))
        #expect(result == "ERROR: Only one display available")
        #expect(tree1.contains(windowId: 100))
    }

    @Test func noFocusedWindowReturnsError() async {
        let engine = WindowEngine(initialMode: .bsp)
        await engine.setCustomDisplayIDsProviderForTesting { [1, 2] }

        let tree1 = BSPTree()
        let tree2 = BSPTree()
        await engine.setDisplayLayoutsForTesting(displayID: 1, tree: tree1)
        await engine.setDisplayLayoutsForTesting(displayID: 2, tree: tree2)

        let result = await engine.execute(command: .windowDisplay(.next))
        #expect(result == "ERROR: No focused window found")
    }

    @Test func moveWindowToEmptyDisplayCreatesTree() async {
        let engine = WindowEngine(initialMode: .bsp)
        await engine.setCustomDisplayIDsProviderForTesting { [1, 2] }

        let tree1 = BSPTree()
        tree1.insert(windowId: 100)
        await engine.setDisplayLayoutsForTesting(displayID: 1, tree: tree1)

        // Display 2 has no layout yet
        let result = await engine.execute(command: .windowDisplay(.next))
        #expect(result == "OK moved window 100 to display 2")
        #expect(!tree1.contains(windowId: 100))
        #expect(tree1.isEmpty)
    }

    @Test func moveWindowInFloatMode() async {
        let engine = WindowEngine(initialMode: .float)
        await engine.setCustomDisplayIDsProviderForTesting { [1, 2] }
        await engine.setCustomBoundsProviderForTesting { id in
            id == 1 ? CGRect(x: 0, y: 0, width: 1920, height: 1080) : CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        }

        let tree1 = BSPTree()
        tree1.insert(windowId: 100)
        await engine.setDisplayLayoutsForTesting(displayID: 1, tree: tree1)
        await engine.registerWindowForTesting(id: 100)

        let result = await engine.execute(command: .windowDisplay(.next))
        #expect(result == "OK moved window 100 to display 2")
        #expect(!tree1.contains(windowId: 100))
    }
}
