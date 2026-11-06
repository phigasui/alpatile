import Foundation
@preconcurrency import ApplicationServices
@preconcurrency import AppKit

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ wid: UnsafeMutablePointer<CGWindowID>) -> AXError

public struct AccessibilityHelper {
    public static func checkAccessibilityPermissions(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static func getWindowID(for element: AXUIElement) -> CGWindowID? {
        var wid: CGWindowID = 0
        let err = _AXUIElementGetWindow(element, &wid)
        if err == .success && wid != 0 {
            return wid
        }
        return nil
    }

    public static func getFrame(for element: AXUIElement) -> CGRect? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let posVal = posValue,
              let sizeVal = sizeValue else {
            return nil
        }

        var origin: CGPoint = .zero
        var size: CGSize = .zero

        guard CFGetTypeID(posVal) == AXValueGetTypeID(),
              CFGetTypeID(sizeVal) == AXValueGetTypeID() else {
            return nil
        }
        let posAxVal = posVal as! AXValue
        let sizeAxVal = sizeVal as! AXValue

        guard AXValueGetValue(posAxVal, .cgPoint, &origin),
              AXValueGetValue(sizeAxVal, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: origin, size: size)
    }

    public static func setPosition(_ origin: CGPoint, for element: AXUIElement) -> Bool {
        var point = origin
        guard let value = AXValueCreate(.cgPoint, &point) else { return false }
        let err = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
        return err == .success
    }

    public static func setSize(_ size: CGSize, for element: AXUIElement) -> Bool {
        var sz = size
        guard let value = AXValueCreate(.cgSize, &sz) else { return false }
        let err = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
        return err == .success
    }

    public static func setEnhancedUserInterface(_ enabled: Bool, onAppElement appElement: AXUIElement) {
        let key = "AXEnhancedUserInterface" as CFString
        let value: CFBoolean = enabled ? kCFBooleanTrue : kCFBooleanFalse
        AXUIElementSetAttributeValue(appElement, key, value)
    }

    public static func getFocusedWindow() -> (element: AXUIElement, windowId: CGWindowID, pid: pid_t)? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedVal) == .success,
              let focused = focusedVal else {
            return nil
        }

        guard CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return nil
        }
        let windowElement = focused as! AXUIElement
        guard let wid = getWindowID(for: windowElement) else {
            return nil
        }

        return (element: windowElement, windowId: wid, pid: pid)
    }
}
