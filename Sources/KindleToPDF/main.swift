import Foundation
import KindleToPDFCore

@main
struct KindleToPDFCLI {
    static func main() {
        do {
            switch try CLIParser.parse(Array(CommandLine.arguments.dropFirst())) {
            case .help:
                print("kindle-to-pdf capture --output <path> --pages <count>")
            case .capture:
                print("capture")
            }
        } catch {
            fputs("エラー: \(error)\n", stderr)
            Foundation.exit(EXIT_FAILURE)
        }
    }
}
