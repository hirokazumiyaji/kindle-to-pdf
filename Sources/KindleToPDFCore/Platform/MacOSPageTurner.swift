import Carbon.HIToolbox
import CoreGraphics

public struct MacOSPageTurner: PageTurning {
    public init() {}

    public func turn(window: KindleWindow, key: NextKey) throws {
        let virtualKey: CGKeyCode
        switch key {
        case .right:
            virtualKey = CGKeyCode(kVK_RightArrow)
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
        keyDown.postToPid(pid_t(window.processID))
        keyUp.postToPid(pid_t(window.processID))
    }
}
