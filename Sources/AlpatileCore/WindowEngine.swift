import Foundation
@preconcurrency import CoreGraphics
@preconcurrency import AppKit
@preconcurrency import ApplicationServices

public actor WindowEngine {
    public private(set) var tree: BSPTree
    public private(set) var config: Config
    public private(set) var layoutMode: LayoutMode
    public let frameApplier: FrameApplier

    public struct WindowEntry: @unchecked Sendable {
        public let id: WindowID
        public let pid: pid_t
        public let appName: String
        public let title: String
        public let element: AXUIElement

        public init(id: WindowID, pid: pid_t, appName: String, title: String, element: AXUIElement) {
            self.id = id
            self.pid = pid
            self.appName = appName
            self.title = title
            self.element = element
        }
    }

    private var registeredWindows: [WindowID: WindowEntry] = [:]

    public init(config: Config = .load(), initialMode: LayoutMode = .bsp) {
        self.tree = BSPTree()
        self.config = config
        self.layoutMode = initialMode
        self.frameApplier = FrameApplier()
    }

    public func reloadConfig() {
        self.config = Config.load()
    }

    public func updateConfig(_ newConfig: Config) {
        self.config = newConfig
    }

    public func getVisibleScreenAXBounds() -> CGRect {
        guard let screen = NSScreen.main else {
            return CGRect(x: 0, y: 0, width: 1920, height: 1080)
        }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        return CGRect.convertCocoaVisibleFrameToAX(cocoaFrame: screen.visibleFrame, primaryScreenHeight: primaryHeight)
    }

    public func registerWindow(id: WindowID, pid: pid_t, appName: String, title: String, element: AXUIElement) {
        registeredWindows[id] = WindowEntry(id: id, pid: pid, appName: appName, title: title, element: element)
        if !tree.contains(windowId: id) {
            let focusedId = AccessibilityHelper.getFocusedWindow()?.windowId
            tree.insert(windowId: id, near: focusedId)
        }
    }

    public func unregisterWindow(id: WindowID) {
        registeredWindows.removeValue(forKey: id)
        tree.remove(windowId: id)
    }

    public func execute(command: Command) async -> String {
        switch command {
        case .ping:
            return "OK pong"

        case .help(let text):
            return text

        case .reloadConfig:
            reloadConfig()
            await retile()
            return "OK reloaded config"

        case .queryStatus:
            let windowCount = tree.allWindowIDs().count
            return "OK layout=\(layoutMode.rawValue) windows=\(windowCount) gap=\(config.windowGap)"

        case .queryWindows:
            let ids = tree.allWindowIDs()
            var lines = ["OK \(ids.count) windows:"]
            for id in ids {
                if let entry = registeredWindows[id] {
                    lines.append("  [\(id)] \(entry.appName): \(entry.title)")
                } else {
                    lines.append("  [\(id)] (unregistered)")
                }
            }
            return lines.joined(separator: "\n")

        case .spaceLayout(let mode):
            layoutMode = mode
            if mode == .bsp {
                await retile()
            }
            return "OK layout set to \(mode.rawValue)"

        case .spaceBalance:
            tree.balance()
            if layoutMode == .bsp {
                await retile()
            }
            return "OK balanced"

        case .spaceRotate(let deg):
            if deg == 90 || deg == 270 {
                tree.rotate90()
                if deg == 270 {
                    tree.rotate90()
                    tree.rotate90()
                }
                if layoutMode == .bsp {
                    await retile()
                }
                return "OK rotated \(deg) deg"
            }
            return "ERROR: only 90 or 270 deg rotation supported"

        case .windowToggleSplit:
            guard let focused = getEffectiveFocusedWindow() else {
                return "ERROR: No focused window found"
            }
            let success = tree.toggleSplit(for: focused)
            if success && layoutMode == .bsp {
                await retile()
                return "OK toggled split for window \(focused)"
            } else if !success {
                return "ERROR: Window \(focused) could not toggle split (single window or not in tree)"
            }
            return "OK toggled split"

        case .windowMaximize:
            guard let focused = getEffectiveFocusedWindow() else {
                return "ERROR: No focused window found"
            }
            let screenBounds = getVisibleScreenAXBounds()
            let targetRect = CGRect(
                x: screenBounds.origin.x + config.leftPadding,
                y: screenBounds.origin.y + config.topPadding,
                width: max(0, screenBounds.width - config.leftPadding - config.rightPadding),
                height: max(0, screenBounds.height - config.topPadding - config.bottomPadding)
            )

            if let entry = registeredWindows[focused] {
                let change = FrameApplier.WindowChange(windowId: focused, pid: entry.pid, targetRect: targetRect)
                await frameApplier.apply(changes: [change]) { _, _ in
                    return entry.element
                }
                return "OK maximized window \(focused)"
            } else {
                return "ERROR: Focused window \(focused) not registered"
            }

        case .windowWarp(let direction):
            guard let focused = getEffectiveFocusedWindow() else {
                return "ERROR: No focused window found"
            }
            let screenBounds = getVisibleScreenAXBounds()
            let swapped = tree.warp(
                windowId: focused,
                direction: direction,
                bounds: screenBounds,
                gap: config.windowGap,
                topPadding: config.topPadding,
                bottomPadding: config.bottomPadding,
                leftPadding: config.leftPadding,
                rightPadding: config.rightPadding
            )
            if let swappedWith = swapped {
                if layoutMode == .bsp {
                    await retile()
                }
                return "OK warped window \(focused) \(direction.rawValue) with \(swappedWith)"
            } else {
                return "OK warp \(direction.rawValue): no neighbor in that direction"
            }
        }
    }

    private func getEffectiveFocusedWindow() -> WindowID? {
        if let focused = AccessibilityHelper.getFocusedWindow() {
            if tree.contains(windowId: focused.windowId) {
                return focused.windowId
            }
        }
        return tree.allWindowIDs().first
    }

    public func retile() async {
        guard layoutMode == .bsp else { return }
        let screenBounds = getVisibleScreenAXBounds()
        let frames = tree.calculateFrames(
            bounds: screenBounds,
            gap: config.windowGap,
            topPadding: config.topPadding,
            bottomPadding: config.bottomPadding,
            leftPadding: config.leftPadding,
            rightPadding: config.rightPadding
        )

        var changes: [FrameApplier.WindowChange] = []
        for (id, rect) in frames {
            if let entry = registeredWindows[id] {
                changes.append(FrameApplier.WindowChange(windowId: id, pid: entry.pid, targetRect: rect))
            }
        }

        let currentEntries = registeredWindows
        await frameApplier.apply(changes: changes) { id, _ in
            currentEntries[id]?.element
        }
    }

    /// Scans active application windows and syncs with the BSPTree.
    public func scanAndSyncWindows() async {
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        var foundIDs: Set<WindowID> = []
        let runningApps = NSWorkspace.shared.runningApplications
        let appByPid = Dictionary(runningApps.map { ($0.processIdentifier, $0) }, uniquingKeysWith: { first, _ in first })

        for winInfo in windowInfoList {
            guard let layer = winInfo[kCGWindowLayer as String] as? Int, layer == 0,
                  let wid = winInfo[kCGWindowNumber as String] as? CGWindowID,
                  let pid = winInfo[kCGWindowOwnerPID as String] as? pid_t,
                  let ownerName = winInfo[kCGWindowOwnerName as String] as? String,
                  let alpha = winInfo[kCGWindowAlpha as String] as? Double, alpha > 0,
                  let boundsDict = winInfo[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width > 100 && bounds.height > 100 else {
                continue
            }

            if config.shouldIgnore(appName: ownerName) {
                continue
            }

            guard let app = appByPid[pid] ?? NSRunningApplication(processIdentifier: pid),
                  app.activationPolicy == .regular else {
                continue
            }

            foundIDs.insert(wid)

            if registeredWindows[wid] == nil {
                let appElement = AXUIElementCreateApplication(pid)
                var windowsValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                   let axWindows = windowsValue as? [AXUIElement] {
                    for axWin in axWindows {
                        if AccessibilityHelper.getWindowID(for: axWin) == wid {
                            let title = (winInfo[kCGWindowName as String] as? String) ?? ""
                            registerWindow(id: wid, pid: pid, appName: ownerName, title: title, element: axWin)
                            break
                        }
                    }
                }
            }
        }

        // Remove windows that are no longer on screen
        for id in tree.allWindowIDs() {
            if !foundIDs.contains(id) {
                unregisterWindow(id: id)
            }
        }

        if layoutMode == .bsp {
            await retile()
        }
    }
}
