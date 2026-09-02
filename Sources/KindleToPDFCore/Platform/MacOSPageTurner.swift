import Carbon.HIToolbox
import CoreGraphics

public struct MacOSPageTurner: PageTurning {
    public init() {}

    public func turn(window: KindleWindow, key: NextKey) throws {
        let virtualKey: CGKeyCode
        switch key {
        case .right:
            virtualKey = CGKeyCode(kVK_RightArrow)
        case .left:
            virtualKey = CGKeyCode(kVK_LeftArrow)
        case .pagedown:
            virtualKey = CGKeyCode(kVK_PageDown)
        }

        guard let keyDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: virtualKey,
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: virtualKey,
            keyDown: false
        ) else {
            throw PlatformError.unableToCreateKeyboardEvent
        }

        // Kindle ignores process-targeted key events unless it is frontmost.
        // Post through the HID tap after activation so the frontmost Kindle receives them.
        _ = window.processID
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
