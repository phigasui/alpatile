import Foundation
@preconcurrency import CoreGraphics
@preconcurrency import AppKit
@preconcurrency import ApplicationServices

public actor WindowEngine {
    public private(set) var config: Config
    public private(set) var layoutMode: LayoutMode
    public let frameApplier: FrameApplier

    /// BSP trees of one display. A display can have several trees (one per macOS Space);
    /// only the tree of the currently visible Space is `active`, the others are kept so the
    /// layout comes back unchanged when the user switches back to that Space.
    struct DisplayLayouts {
        var trees: [BSPTree] = []
        var active: BSPTree?
    }

    private var displays: [CGDirectDisplayID: DisplayLayouts] = [:]
    private var lastVisible: Set<WindowID> = []

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

    // MARK: - Display helpers

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    private func mainDisplayID() -> CGDirectDisplayID? {
        NSScreen.main.flatMap { Self.displayID(of: $0) }
    }

    /// Visible area (excluding menu bar / Dock) of the given display in AX coordinates.
    private func visibleAXBounds(of displayID: CGDirectDisplayID) -> CGRect {
        let screens = NSScreen.screens
        let primaryHeight = screens.first?.frame.height ?? 1080
        let screen = screens.first(where: { Self.displayID(of: $0) == displayID }) ?? NSScreen.main ?? screens.first
        guard let screen else {
            return CGRect(x: 0, y: 0, width: 1920, height: 1080)
        }
        return CGRect.convertCocoaVisibleFrameToAX(cocoaFrame: screen.visibleFrame, primaryScreenHeight: primaryHeight)
    }

    private func activeTree(of displayID: CGDirectDisplayID) -> BSPTree? {
        displays[displayID]?.active
    }

    private var allActiveTrees: [(displayID: CGDirectDisplayID, tree: BSPTree)] {
        displays.compactMap { entry in
            entry.value.active.map { (displayID: entry.key, tree: $0) }
        }
    }

    private func activeWindowCount() -> Int {
        allActiveTrees.reduce(0) { $0 + $1.tree.allWindowIDs().count }
    }

    /// Finds the display (and its active tree) that holds the given window.
    private func locate(windowId: WindowID) -> (displayID: CGDirectDisplayID, tree: BSPTree)? {
        allActiveTrees.first { $0.tree.contains(windowId: windowId) }
    }

    /// The focused window and the display it lives on. Falls back to the first window on the main display.
    private func getEffectiveFocused() -> (windowId: WindowID, displayID: CGDirectDisplayID, tree: BSPTree)? {
        if let focused = AccessibilityHelper.getFocusedWindow(),
           let found = locate(windowId: focused.windowId) {
            return (focused.windowId, found.displayID, found.tree)
        }
        if let main = mainDisplayID(), let tree = activeTree(of: main), let first = tree.allWindowIDs().first {
            return (first, main, tree)
        }
        for entry in allActiveTrees {
            if let first = entry.tree.allWindowIDs().first {
                return (first, entry.displayID, entry.tree)
            }
        }
        return nil
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
            return "OK layout=\(layoutMode.rawValue) windows=\(activeWindowCount()) displays=\(allActiveTrees.count) gap=\(config.windowGap)"

        case .queryWindows:
            let trees = allActiveTrees
            let total = trees.reduce(0) { $0 + $1.tree.allWindowIDs().count }
            var lines = ["OK \(total) windows:"]
            for (displayID, tree) in trees.sorted(by: { $0.displayID < $1.displayID }) {
                for id in tree.allWindowIDs() {
                    if let entry = registeredWindows[id] {
                        lines.append("  [\(id)] display=\(displayID) \(entry.appName): \(entry.title)")
                    } else {
                        lines.append("  [\(id)] display=\(displayID) (unregistered)")
                    }
                }
            }
            return lines.joined(separator: "\n")

        case .spaceLayout(let mode):
            layoutMode = mode
            if mode == .bsp {
                // Pick up windows opened since the last sync, then tile every display.
                await scanAndSyncWindows()
                await retile()
            }
            return "OK layout set to \(mode.rawValue)"

        case .spaceBalance:
            guard let focused = getEffectiveFocused() else {
                return "ERROR: No focused window found"
            }
            focused.tree.balance()
            await retile(displayID: focused.displayID)
            return "OK balanced"

        case .spaceRotate(let deg):
            guard deg == 90 || deg == 270 else {
                return "ERROR: only 90 or 270 deg rotation supported"
            }
            guard let focused = getEffectiveFocused() else {
                return "ERROR: No focused window found"
            }
            focused.tree.rotate90()
            if deg == 270 {
                focused.tree.rotate90()
                focused.tree.rotate90()
            }
            await retile(displayID: focused.displayID)
            return "OK rotated \(deg) deg"

        case .windowToggleSplit:
            guard let focused = getEffectiveFocused() else {
                return "ERROR: No focused window found"
            }
            guard focused.tree.toggleSplit(for: focused.windowId) else {
                return "ERROR: Window \(focused.windowId) could not toggle split (single window or not in tree)"
            }
            await retile(displayID: focused.displayID)
            return "OK toggled split for window \(focused.windowId)"

        case .windowMaximize:
            guard let focused = getEffectiveFocused() else {
                return "ERROR: No focused window found"
            }
            let screenBounds = visibleAXBounds(of: focused.displayID)
            let targetRect = CGRect(
                x: screenBounds.origin.x + config.leftPadding,
                y: screenBounds.origin.y + config.topPadding,
                width: max(0, screenBounds.width - config.leftPadding - config.rightPadding),
                height: max(0, screenBounds.height - config.topPadding - config.bottomPadding)
            )

            if let entry = registeredWindows[focused.windowId] {
                let change = FrameApplier.WindowChange(windowId: focused.windowId, pid: entry.pid, targetRect: targetRect)
                await frameApplier.apply(changes: [change]) { _, _ in
                    return entry.element
                }
                return "OK maximized window \(focused.windowId)"
            } else {
                return "ERROR: Focused window \(focused.windowId) not registered"
            }

        case .windowWarp(let direction):
            guard let focused = getEffectiveFocused() else {
                return "ERROR: No focused window found"
            }
            let swapped = focused.tree.warp(
                windowId: focused.windowId,
                direction: direction,
                bounds: visibleAXBounds(of: focused.displayID),
                gap: config.windowGap,
                topPadding: config.topPadding,
                bottomPadding: config.bottomPadding,
                leftPadding: config.leftPadding,
                rightPadding: config.rightPadding
            )
            if let swappedWith = swapped {
                await retile(displayID: focused.displayID)
                return "OK warped window \(focused.windowId) \(direction.rawValue) with \(swappedWith)"
            } else {
                return "OK warp \(direction.rawValue): no neighbor in that direction"
            }
        }
    }

    // MARK: - Tiling

    /// Tiles the active tree of every display (or only the given one).
    public func retile(displayID: CGDirectDisplayID? = nil) async {
        guard layoutMode == .bsp else { return }

        var changes: [FrameApplier.WindowChange] = []
        for (id, tree) in allActiveTrees where displayID == nil || displayID == id {
            let frames = tree.calculateFrames(
                bounds: visibleAXBounds(of: id),
                gap: config.windowGap,
                topPadding: config.topPadding,
                bottomPadding: config.bottomPadding,
                leftPadding: config.leftPadding,
                rightPadding: config.rightPadding
            )
            for (windowId, rect) in frames {
                if let entry = registeredWindows[windowId] {
                    changes.append(FrameApplier.WindowChange(windowId: windowId, pid: entry.pid, targetRect: rect))
                }
            }
        }

        let currentEntries = registeredWindows
        await frameApplier.apply(changes: changes) { id, _ in
            currentEntries[id]?.element
        }
    }

    // MARK: - Window sync

    private struct VisibleWindow {
        let id: WindowID
        let pid: pid_t
        let appName: String
        let title: String
    }

    /// Scans the windows visible right now (all displays) and syncs them with the per-display trees.
    ///
    /// Windows of other Spaces are not on screen, so they are simply absent from the scan. Their layout
    /// is kept in a saved tree and is restored when the same set of windows becomes visible again,
    /// instead of being rebuilt (and re-tiled) on every Space switch.
    public func scanAndSyncWindows() async {
        guard let windowInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        let runningApps = NSWorkspace.shared.runningApplications
        let appByPid = Dictionary(runningApps.map { ($0.processIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        let fallbackDisplay = mainDisplayID() ?? CGMainDisplayID()

        var visibleByDisplay: [CGDirectDisplayID: [VisibleWindow]] = [:]
        var visibleIDs: Set<WindowID> = []

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

            // The display that contains the window's center (CG window bounds share AX's top-left coordinates).
            var displayID: CGDirectDisplayID = 0
            var displayCount: UInt32 = 0
            CGGetDisplaysWithPoint(bounds.center, 1, &displayID, &displayCount)
            if displayCount == 0 {
                displayID = fallbackDisplay
            }

            let title = (winInfo[kCGWindowName as String] as? String) ?? ""
            visibleByDisplay[displayID, default: []].append(
                VisibleWindow(id: wid, pid: pid, appName: ownerName, title: title)
            )
            visibleIDs.insert(wid)
        }

        // (Re)acquire AX elements for new windows and for windows that came back from another Space.
        var axWindowsByPid: [pid_t: [AXUIElement]] = [:]
        for windows in visibleByDisplay.values {
            for win in windows where registeredWindows[win.id] == nil || !lastVisible.contains(win.id) {
                if axWindowsByPid[win.pid] == nil {
                    var windowsValue: CFTypeRef?
                    let appElement = AXUIElementCreateApplication(win.pid)
                    if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                       let axWindows = windowsValue as? [AXUIElement] {
                        axWindowsByPid[win.pid] = axWindows
                    } else {
                        axWindowsByPid[win.pid] = []
                    }
                }
                if let axWin = axWindowsByPid[win.pid]?.first(where: { AccessibilityHelper.getWindowID(for: $0) == win.id }) {
                    registeredWindows[win.id] = WindowEntry(
                        id: win.id, pid: win.pid, appName: win.appName, title: win.title, element: axWin
                    )
                }
            }
        }

        let focusedId = AccessibilityHelper.getFocusedWindow()?.windowId
        var changedDisplays: [CGDirectDisplayID] = []

        for (displayID, windows) in visibleByDisplay {
            // Only windows we could get an AX element for can be tiled.
            let ids = windows.map(\.id).filter { registeredWindows[$0] != nil }
            var layouts = displays[displayID] ?? DisplayLayouts()

            let tree = Self.selectTree(for: Set(ids), among: layouts.trees, preferring: layouts.active) ?? {
                let created = BSPTree()
                layouts.trees.append(created)
                return created
            }()
            layouts.active = tree

            var changed = false
            let idSet = Set(ids)
            for existing in tree.allWindowIDs() where !idSet.contains(existing) {
                tree.remove(windowId: existing)
                changed = true
            }
            for id in ids where !tree.contains(windowId: id) {
                // A window dragged to another display leaves its old tree.
                for other in allActiveTrees where other.displayID != displayID {
                    other.tree.remove(windowId: id)
                }
                tree.insert(windowId: id, near: focusedId)
                changed = true
            }

            layouts.trees.removeAll { $0 !== tree && $0.isEmpty }
            displays[displayID] = layouts
            if changed { changedDisplays.append(displayID) }
        }

        // Displays with nothing visible have no active tree (their Space's layout stays saved).
        for displayID in displays.keys where visibleByDisplay[displayID] == nil {
            displays[displayID]?.active = nil
        }

        lastVisible = visibleIDs
        let kept = Set(displays.values.flatMap { $0.trees.flatMap { $0.allWindowIDs() } })
        registeredWindows = registeredWindows.filter { kept.contains($0.key) }

        for displayID in changedDisplays {
            await retile(displayID: displayID)
        }
    }

    /// Picks the saved tree that belongs to the Space currently showing `visible` windows.
    /// A tree matches when it shares more than half of the visible windows, which keeps windows
    /// that appear on every Space from gluing different Spaces together.
    static func selectTree(for visible: Set<WindowID>, among trees: [BSPTree], preferring active: BSPTree?) -> BSPTree? {
        var best: BSPTree?
        var bestOverlap = 0
        for tree in trees {
            let overlap = tree.allWindowIDs().filter { visible.contains($0) }.count
            guard overlap * 2 > visible.count else { continue }
            if overlap > bestOverlap || (overlap == bestOverlap && tree === active) {
                best = tree
                bestOverlap = overlap
            }
        }
        return best
    }
}
