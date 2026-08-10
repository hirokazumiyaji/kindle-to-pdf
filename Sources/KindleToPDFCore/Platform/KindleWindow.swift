import CoreGraphics
import Foundation

public struct KindleWindow: Equatable {
    public let windowID: UInt32
    public let processID: Int32
    public let title: String
    public let bounds: CGRect

    public init(windowID: UInt32, processID: Int32, title: String, bounds: CGRect) {
        self.windowID = windowID
        self.processID = processID
        self.title = title
        self.bounds = bounds
    }
}

public enum PlatformError: Error, Equatable, CustomStringConvertible {
    case noKindleApplication
    case noWindows
    case ambiguousWindows
    case titleNotFound(String)
    case missingPermissions([String])
    case unableToCreateKeyboardEvent
    case unableToCaptureWindow(UInt32)

    public var description: String {
        switch self {
        case .noKindleApplication:
            return "Kindleアプリが起動していません。"
        case .noWindows:
            return "Kindleウィンドウが見つかりません。"
        case .ambiguousWindows:
            return "対象Kindleウィンドウを一意に特定できません。--windowを指定してください。"
        case let .titleNotFound(title):
            return "指定したKindleウィンドウが見つかりません: \(title)"
        case let .missingPermissions(permissions):
            return "次のmacOS権限が必要です: \(permissions.joined(separator: ", "))"
        case .unableToCreateKeyboardEvent:
            return "ページ送り用のキーボードイベントを作成できません。"
        case let .unableToCaptureWindow(windowID):
            return "Kindleウィンドウをキャプチャできません: \(windowID)"
        }
    }
}
