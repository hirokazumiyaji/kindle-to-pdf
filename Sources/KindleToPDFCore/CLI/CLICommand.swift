import Foundation

public enum NextKey: String, Equatable, Codable {
    case right
    case left
    case pagedown

    public var alternate: NextKey? {
        switch self {
        case .right:
            return .left
        case .left:
            return .right
        case .pagedown:
            return .left
        }
    }
}

public struct CaptureOptions: Equatable {
    public let outputURL: URL
    public let pageCount: Int?
    public let windowTitle: String?
    public let nextKey: NextKey
    public let sessionURL: URL?
    public let resume: Bool
    public let overwrite: Bool

    public init(
        outputURL: URL,
        pageCount: Int?,
        windowTitle: String?,
        nextKey: NextKey,
        sessionURL: URL?,
        resume: Bool,
        overwrite: Bool
    ) {
        self.outputURL = outputURL
        self.pageCount = pageCount
        self.windowTitle = windowTitle
        self.nextKey = nextKey
        self.sessionURL = sessionURL
        self.resume = resume
        self.overwrite = overwrite
    }

    public var requestedPageCountForSession: Int {
        pageCount ?? 0
    }
}

public enum CLICommand: Equatable {
    case capture(CaptureOptions)
    case help
}

public enum CLIError: Error, Equatable, CustomStringConvertible {
    case missingSubcommand
    case missingValue(String)
    case missingOption(String)
    case invalidValue(String, String)
    case unknownOption(String)

    public var description: String {
        switch self {
        case .missingSubcommand:
            return "コマンドを指定してください。"
        case let .missingValue(option):
            return "オプション \(option) の値を指定してください。"
        case let .missingOption(option):
            return "必須オプション \(option) を指定してください。"
        case let .invalidValue(option, value):
            return "オプション \(option) の値が不正です: \(value)"
        case let .unknownOption(option):
            return "不明なオプションです: \(option)"
        }
    }
}
