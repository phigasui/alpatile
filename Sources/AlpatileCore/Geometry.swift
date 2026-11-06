import Foundation
import CoreGraphics

public extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    func isNearlyEqual(to other: CGRect, tolerance: CGFloat = 1.0) -> Bool {
        abs(origin.x - other.origin.x) <= tolerance &&
        abs(origin.y - other.origin.y) <= tolerance &&
        abs(size.width - other.size.width) <= tolerance &&
        abs(size.height - other.size.height) <= tolerance
    }

    /// Subdivides the rectangle according to split type and ratio (0.0 to 1.0), accounting for inner gap.
    func split(type: SplitType, ratio: CGFloat, gap: CGFloat = 0.0) -> (CGRect, CGRect) {
        let clampedRatio = max(0.05, min(0.95, ratio))
        switch type {
        case .vertical:
            // Left and Right
            let availableWidth = max(0, width - gap)
            let leftWidth = floor(availableWidth * clampedRatio)
            let rightWidth = availableWidth - leftWidth
            let leftRect = CGRect(x: origin.x, y: origin.y, width: leftWidth, height: height)
            let rightRect = CGRect(x: origin.x + leftWidth + gap, y: origin.y, width: rightWidth, height: height)
            return (leftRect, rightRect)

        case .horizontal:
            // Top and Bottom (AX coordinates: y increases downwards)
            let availableHeight = max(0, height - gap)
            let topHeight = floor(availableHeight * clampedRatio)
            let bottomHeight = availableHeight - topHeight
            let topRect = CGRect(x: origin.x, y: origin.y, width: width, height: topHeight)
            let bottomRect = CGRect(x: origin.x, y: origin.y + topHeight + gap, width: width, height: bottomHeight)
            return (topRect, bottomRect)
        }
    }

    /// Converts Cocoa visible frame (origin at bottom-left) to AX coordinates (origin at top-left).
    static func convertCocoaVisibleFrameToAX(cocoaFrame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        let axX = cocoaFrame.origin.x
        let axY = primaryScreenHeight - (cocoaFrame.origin.y + cocoaFrame.height)
        return CGRect(x: axX, y: axY, width: cocoaFrame.width, height: cocoaFrame.height)
    }
}

public struct GeometryHelper {
    /// Finds the best neighbor in a given direction among candidate rectangles.
    public static func findNeighbor(
        from source: CGRect,
        among candidates: [(id: WindowID, rect: CGRect)],
        direction: Direction
    ) -> WindowID? {
        var bestId: WindowID?
        var bestDistance: CGFloat = .infinity

        for (candId, candRect) in candidates {
            guard !candRect.isNearlyEqual(to: source) else { continue }

            let isValidDirection: Bool
            let primaryDistance: CGFloat
            let secondaryDistance: CGFloat

            switch direction {
            case .west:
                // Candidate must be to the left
                isValidDirection = candRect.maxX <= source.minX + 2.0
                primaryDistance = source.minX - candRect.maxX
                // Overlap on Y
                let overlapY = max(0, min(source.maxY, candRect.maxY) - max(source.minY, candRect.minY))
                secondaryDistance = overlapY > 0 ? 0 : abs(source.center.y - candRect.center.y)

            case .east:
                // Candidate must be to the right
                isValidDirection = candRect.minX >= source.maxX - 2.0
                primaryDistance = candRect.minX - source.maxX
                let overlapY = max(0, min(source.maxY, candRect.maxY) - max(source.minY, candRect.minY))
                secondaryDistance = overlapY > 0 ? 0 : abs(source.center.y - candRect.center.y)

            case .north:
                // Candidate must be above (smaller Y in AX coordinate space)
                isValidDirection = candRect.maxY <= source.minY + 2.0
                primaryDistance = source.minY - candRect.maxY
                let overlapX = max(0, min(source.maxX, candRect.maxX) - max(source.minX, candRect.minX))
                secondaryDistance = overlapX > 0 ? 0 : abs(source.center.x - candRect.center.x)

            case .south:
                // Candidate must be below (larger Y in AX coordinate space)
                isValidDirection = candRect.minY >= source.maxY - 2.0
                primaryDistance = candRect.minY - source.maxY
                let overlapX = max(0, min(source.maxX, candRect.maxX) - max(source.minX, candRect.minX))
                secondaryDistance = overlapX > 0 ? 0 : abs(source.center.x - candRect.center.x)
            }

            if isValidDirection {
                // Prioritize overlapping rectangles, then closest distance
                let totalScore = primaryDistance * 2.0 + secondaryDistance
                if totalScore < bestDistance {
                    bestDistance = totalScore
                    bestId = candId
                }
            }
        }

        return bestId
    }
}
