import Foundation

public enum SessionStatus: String, Codable, Equatable {
    case capturing
    case completed
}

public struct SessionState: Codable, Equatable {
    public let schemaVersion: Int
    public let outputPath: String
    public let requestedPageCount: Int
    public var capturedPageCount: Int
    public let windowTitle: String?
    public let windowID: UInt32?
    public let processID: Int32?
    public var lastImageHash: String?
    public var status: SessionStatus

    public init(
        schemaVersion: Int,
        outputPath: String,
        requestedPageCount: Int,
        capturedPageCount: Int,
        windowTitle: String?,
        windowID: UInt32?,
        processID: Int32?,
        lastImageHash: String?,
        status: SessionStatus
    ) {
        self.schemaVersion = schemaVersion
        self.outputPath = outputPath
        self.requestedPageCount = requestedPageCount
        self.capturedPageCount = capturedPageCount
        self.windowTitle = windowTitle
        self.windowID = windowID
        self.processID = processID
        self.lastImageHash = lastImageHash
        self.status = status
    }
}

public enum SessionError: Error, Equatable, CustomStringConvertible {
    case invalidPageIndex(Int)
    case missingState(URL)
    case invalidState(URL)

    public var description: String {
        switch self {
        case let .invalidPageIndex(index):
            return "ページ番号が不正です: \(index)"
        case let .missingState(url):
            return "セッション状態が見つかりません: \(url.path)"
        case let .invalidState(url):
            return "セッション状態を読み込めません: \(url.path)"
        }
    }
}
