import Foundation
import CoreGraphics

public final class BSPNode: @unchecked Sendable {
    public var windowId: WindowID?
    public var splitType: SplitType
    public var ratio: CGFloat
    public var firstChild: BSPNode?
    public var secondChild: BSPNode?
    public weak var parent: BSPNode?

    public var isLeaf: Bool {
        firstChild == nil && secondChild == nil
    }

    public init(windowId: WindowID? = nil, splitType: SplitType = .vertical, ratio: CGFloat = 0.5) {
        self.windowId = windowId
        self.splitType = splitType
        self.ratio = ratio
        self.firstChild = nil
        self.secondChild = nil
        self.parent = nil
    }

    public convenience init(
        splitType: SplitType,
        ratio: CGFloat = 0.5,
        first: BSPNode,
        second: BSPNode
    ) {
        self.init(windowId: nil, splitType: splitType, ratio: ratio)
        self.firstChild = first
        self.secondChild = second
        first.parent = self
        second.parent = self
    }
}

public final class BSPTree: @unchecked Sendable {
    public private(set) var root: BSPNode?

    public init(root: BSPNode? = nil) {
        self.root = root
    }

    public var isEmpty: Bool {
        root == nil
    }

    public func allWindowIDs() -> [WindowID] {
        guard let root = root else { return [] }
        var result: [WindowID] = []
        func traverse(_ node: BSPNode) {
            if node.isLeaf, let id = node.windowId {
                result.append(id)
            } else {
                if let first = node.firstChild { traverse(first) }
                if let second = node.secondChild { traverse(second) }
            }
        }
        traverse(root)
        return result
    }

    public func contains(windowId: WindowID) -> Bool {
        findLeaf(windowId: windowId) != nil
    }

    public func findLeaf(windowId: WindowID) -> BSPNode? {
        guard let root = root else { return nil }
        var queue = [root]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current.isLeaf {
                if current.windowId == windowId {
                    return current
                }
            } else {
                if let first = current.firstChild { queue.append(first) }
                if let second = current.secondChild { queue.append(second) }
            }
        }
        return nil
    }

    private func findFirstLeaf() -> BSPNode? {
        guard let root = root else { return nil }
        var current = root
        while !current.isLeaf {
            if let first = current.firstChild {
                current = first
            } else if let second = current.secondChild {
                current = second
            } else {
                break
            }
        }
        return current
    }

    @discardableResult
    public func insert(windowId: WindowID, near targetId: WindowID? = nil) -> Bool {
        if contains(windowId: windowId) {
            return false // already present
        }

        guard let currentRoot = root else {
            root = BSPNode(windowId: windowId)
            return true
        }

        let targetLeaf: BSPNode
        if let targetId = targetId, let leaf = findLeaf(windowId: targetId) {
            targetLeaf = leaf
        } else if let firstLeaf = findFirstLeaf() {
            targetLeaf = firstLeaf
        } else {
            targetLeaf = currentRoot
        }

        let newLeaf = BSPNode(windowId: windowId)

        if targetLeaf === currentRoot && currentRoot.isLeaf {
            // Root is leaf, split root
            let newRoot = BSPNode(
                splitType: .vertical,
                ratio: 0.5,
                first: targetLeaf,
                second: newLeaf
            )
            self.root = newRoot
            return true
        }

        // Target leaf is inside tree or is an internal node
        let parent = targetLeaf.parent
        let splitType: SplitType = (parent?.splitType == .vertical) ? .horizontal : .vertical
        let newInternal = BSPNode(
            splitType: splitType,
            ratio: 0.5,
            first: targetLeaf,
            second: newLeaf
        )
        newInternal.parent = parent

        if let parent = parent {
            if parent.firstChild === targetLeaf {
                parent.firstChild = newInternal
            } else {
                parent.secondChild = newInternal
            }
        } else {
            self.root = newInternal
        }

        return true
    }

    @discardableResult
    public func remove(windowId: WindowID) -> Bool {
        guard let leaf = findLeaf(windowId: windowId) else {
            return false
        }

        guard let parent = leaf.parent else {
            // Leaf is the only node in the tree
            root = nil
            return true
        }

        let sibling = (parent.firstChild === leaf) ? parent.secondChild! : parent.firstChild!
        let grandparent = parent.parent

        sibling.parent = grandparent
        if let grandparent = grandparent {
            if grandparent.firstChild === parent {
                grandparent.firstChild = sibling
            } else {
                grandparent.secondChild = sibling
            }
        } else {
            root = sibling
        }

        return true
    }

    @discardableResult
    public func swap(idA: WindowID, idB: WindowID) -> Bool {
        guard let leafA = findLeaf(windowId: idA),
              let leafB = findLeaf(windowId: idB) else {
            return false
        }
        leafA.windowId = idB
        leafB.windowId = idA
        return true
    }

    @discardableResult
    public func toggleSplit(for windowId: WindowID) -> Bool {
        guard let leaf = findLeaf(windowId: windowId),
              let parent = leaf.parent else {
            return false
        }
        parent.splitType = parent.splitType.opposite
        return true
    }

    public func balance() {
        guard let root = root else { return }
        func resetRatio(_ node: BSPNode) {
            if !node.isLeaf {
                node.ratio = 0.5
                if let first = node.firstChild { resetRatio(first) }
                if let second = node.secondChild { resetRatio(second) }
            }
        }
        resetRatio(root)
    }

    public func rotate90() {
        guard let root = root else { return }
        func rotateNode(_ node: BSPNode) {
            if !node.isLeaf {
                let oldSplit = node.splitType
                node.splitType = oldSplit.opposite
                // Clockwise 90-degree rotation in screen coordinates (origin top-left):
                // Vertical -> Horizontal: left becomes top, right becomes bottom (no swap)
                // Horizontal -> Vertical: top becomes right, bottom becomes left (swap required)
                if oldSplit == .horizontal {
                    let temp = node.firstChild
                    node.firstChild = node.secondChild
                    node.secondChild = temp
                }

                if let first = node.firstChild { rotateNode(first) }
                if let second = node.secondChild { rotateNode(second) }
            }
        }
        rotateNode(root)
    }

    public func calculateFrames(
        bounds: CGRect,
        gap: CGFloat = 0,
        topPadding: CGFloat = 0,
        bottomPadding: CGFloat = 0,
        leftPadding: CGFloat = 0,
        rightPadding: CGFloat = 0
    ) -> [(id: WindowID, rect: CGRect)] {
        guard let root = root else { return [] }

        let contentX = bounds.origin.x + leftPadding
        let contentY = bounds.origin.y + topPadding
        let contentW = max(0, bounds.width - leftPadding - rightPadding)
        let contentH = max(0, bounds.height - topPadding - bottomPadding)
        let contentRect = CGRect(x: contentX, y: contentY, width: contentW, height: contentH)

        var result: [(id: WindowID, rect: CGRect)] = []

        func traverse(_ node: BSPNode, rect: CGRect) {
            if node.isLeaf {
                if let id = node.windowId {
                    result.append((id: id, rect: rect))
                }
            } else {
                guard let first = node.firstChild, let second = node.secondChild else { return }
                let (firstRect, secondRect) = rect.split(type: node.splitType, ratio: node.ratio, gap: gap)
                traverse(first, rect: firstRect)
                traverse(second, rect: secondRect)
            }
        }

        traverse(root, rect: contentRect)
        return result
    }

    @discardableResult
    public func warp(
        windowId: WindowID,
        direction: Direction,
        bounds: CGRect,
        gap: CGFloat = 0,
        topPadding: CGFloat = 0,
        bottomPadding: CGFloat = 0,
        leftPadding: CGFloat = 0,
        rightPadding: CGFloat = 0
    ) -> WindowID? {
        let frames = calculateFrames(
            bounds: bounds,
            gap: gap,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
            leftPadding: leftPadding,
            rightPadding: rightPadding
        )

        guard let sourceFrame = frames.first(where: { $0.id == windowId })?.rect else {
            return nil
        }

        let candidates = frames.filter { $0.id != windowId }
        guard let neighborId = GeometryHelper.findNeighbor(from: sourceFrame, among: candidates, direction: direction) else {
            return nil
        }

        swap(idA: windowId, idB: neighborId)
        return neighborId
    }
}
