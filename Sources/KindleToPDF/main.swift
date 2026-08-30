import Dispatch
import Darwin
import Foundation
import KindleToPDFCore

@main
struct KindleToPDFCLI {
    static func main() {
        let stopController = SignalStopController()
        signal(SIGINT, SIG_IGN)
        let signalSource = DispatchSource.makeSignalSource(
            signal: SIGINT,
            queue: DispatchQueue.global(qos: .userInitiated)
        )
        signalSource.setEventHandler {
            stopController.requestStop()
        }
        signalSource.resume()
        defer { signalSource.cancel() }

        do {
            switch try CLIParser.parse(Array(CommandLine.arguments.dropFirst())) {
            case .help:
                print(usage)
            case let .capture(options):
                let coordinator = CaptureCoordinator(
                    windowLocator: MacOSWindowLocator(),
                    permissionChecker: MacOSPermissionChecker(),
                    pageTurner: MacOSPageTurner(),
                    applicationActivator: MacOSApplicationActivator(),
                    windowCapture: MacOSWindowCapture(),
                    imageCodec: PNGImageCodec(),
                    imageChangeDetector: ImageChangeDetector(),
                    pdfWriter: PDFWriter(),
                    sleeper: ThreadSleeper()
                )
                try coordinator.run(
                    options: options,
                    stopRequested: { stopController.isRequested }
                )
                print("PDFを作成しました: \(options.outputURL.path)")
            }
        } catch CaptureError.stopRequested {
            fputs("停止しました。保存済みページはセッションに残っています。\n", stderr)
        } catch {
            fputs("エラー: \(error)\n", stderr)
            Foundation.exit(EXIT_FAILURE)
        }
    }

    private static let usage = """
    Usage:
      kindle-to-pdf capture --output <path> [--pages <count>] [options]

    Options:
      --pages <count>                    取得ページ数（省略時は最終ページまで）
      --window <title>                   Kindleウィンドウのタイトル
      --next-key <right|left|pagedown>   ページ送りキー（既定: right、進まなければ左右を自動切替）
      --session <path>                   セッションディレクトリ
      --resume                           未完了セッションを再開
      --overwrite                        既存PDFを上書き
    """
}
