import Foundation
@preconcurrency import ApplicationServices
import CoreGraphics

public actor FrameApplier {
    private var pendingTransactions: Set<WindowID> = []

    public init() {}

    public func isTransactionPending(for windowId: WindowID) -> Bool {
        pendingTransactions.contains(windowId)
    }

    public struct WindowChange: Sendable {
        public let windowId: WindowID
        public let pid: pid_t
        public let targetRect: CGRect

        public init(windowId: WindowID, pid: pid_t, targetRect: CGRect) {
            self.windowId = windowId
            self.pid = pid
            self.targetRect = targetRect
        }
    }

    /// Applies geometry changes safely with flicker suppression and 1px tolerance guard.
    public func apply(
        changes: [WindowChange],
        elementProvider: @Sendable (WindowID, pid_t) -> AXUIElement?
    ) async {
        for change in changes {
            guard let element = elementProvider(change.windowId, change.pid) else {
                continue
            }

            // 1. 1px tolerance guard
            if let current = AccessibilityHelper.getFrame(for: element),
               current.isNearlyEqual(to: change.targetRect, tolerance: 1.0) {
                continue
            }

            pendingTransactions.insert(change.windowId)

            let appElement = AXUIElementCreateApplication(change.pid)

            // 2. Temporarily disable AXEnhancedUserInterface to prevent stutter animation
            AccessibilityHelper.setEnhancedUserInterface(false, onAppElement: appElement)

            // 3. Safe ordering: Size -> Position -> Size
            _ = AccessibilityHelper.setSize(change.targetRect.size, for: element)
            _ = AccessibilityHelper.setPosition(change.targetRect.origin, for: element)
            _ = AccessibilityHelper.setSize(change.targetRect.size, for: element)

            // 4. Restore AXEnhancedUserInterface and clear pending transaction after 50ms
            let wid = change.windowId
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                AccessibilityHelper.setEnhancedUserInterface(true, onAppElement: appElement)
                await self?.finishTransaction(for: wid)
            }
        }
    }

    private func finishTransaction(for windowId: WindowID) {
        pendingTransactions.remove(windowId)
    }
}
