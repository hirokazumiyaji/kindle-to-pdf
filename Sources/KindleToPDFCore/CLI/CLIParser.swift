import Foundation

public enum CLIParser {
    public static func parse(_ arguments: [String]) throws -> CLICommand {
        guard let command = arguments.first else {
            throw CLIError.missingSubcommand
        }

        if command == "help" || command == "--help" {
            return .help
        }
        guard command == "capture" else {
            throw CLIError.unknownOption(command)
        }

        var outputURL: URL?
        var pageCount: Int?
        var windowTitle: String?
        var nextKey = NextKey.right
        var sessionURL: URL?
        var resume = false
        var overwrite = false
        var index = 1

        while index < arguments.count {
            let option = arguments[index]
            switch option {
            case "--output":
                outputURL = URL(fileURLWithPath: try value(for: option, at: &index, in: arguments))
            case "--pages":
                let value = try value(for: option, at: &index, in: arguments)
                guard let parsed = Int(value), parsed > 0 else {
                    throw CLIError.invalidValue(option, value)
                }
                pageCount = parsed
            case "--window":
                windowTitle = try value(for: option, at: &index, in: arguments)
            case "--next-key":
                let value = try value(for: option, at: &index, in: arguments)
                guard let parsed = NextKey(rawValue: value) else {
                    throw CLIError.invalidValue(option, value)
                }
                nextKey = parsed
            case "--session":
                sessionURL = URL(fileURLWithPath: try value(for: option, at: &index, in: arguments))
            case "--resume":
                resume = true
            case "--overwrite":
                overwrite = true
            default:
                throw CLIError.unknownOption(option)
            }
            index += 1
        }

        guard let outputURL else {
            throw CLIError.missingOption("--output")
        }

        return .capture(CaptureOptions(
            outputURL: outputURL,
            pageCount: pageCount,
            windowTitle: windowTitle,
            nextKey: nextKey,
            sessionURL: sessionURL,
            resume: resume,
            overwrite: overwrite
        ))
    }

    private static func value(
        for option: String,
        at index: inout Int,
        in arguments: [String]
    ) throws -> String {
        index += 1
        guard index < arguments.count else {
            throw CLIError.missingValue(option)
        }
        return arguments[index]
    }
}
