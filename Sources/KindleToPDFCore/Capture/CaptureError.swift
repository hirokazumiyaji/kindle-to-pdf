import Foundation

public enum CaptureError: Error, Equatable, CustomStringConvertible {
    case sessionAlreadyExists(URL)
    case outputAlreadyExists(URL)
    case invalidResume(String)
    case pageDidNotChange(Int)
    case stopRequested

    public var description: String {
        switch self {
        case let .sessionAlreadyExists(url):
            return "未完了セッションが既に存在します: \(url.path)（--resumeを指定してください）"
        case let .outputAlreadyExists(url):
            return "出力PDFが既に存在します: \(url.path)（上書きには--overwriteを指定してください）"
        case let .invalidResume(reason):
            return "セッションを再開できません: \(reason)"
        case let .pageDidNotChange(page):
            return "ページ\(page)への遷移を検出できませんでした。"
        case .stopRequested:
            return "ユーザー操作により停止しました。保存済みページはセッションに残っています。"
        }
    }
}
