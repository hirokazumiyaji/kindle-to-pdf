import ApplicationServices
import CoreGraphics

public struct MacOSPermissionChecker: PermissionChecking {
    private let executablePath: String
    private let accessibilityTrusted: () -> Bool
    private let screenCaptureAuthorized: () -> Bool
    private let requestScreenCapture: () -> Bool

    public init() {
        self.init(
            executablePath: Self.currentExecutablePath,
            accessibilityTrusted: Self.isAccessibilityTrusted,
            screenCaptureAuthorized: CGPreflightScreenCaptureAccess,
            requestScreenCapture: CGRequestScreenCaptureAccess
        )
    }

    init(
        executablePath: String,
        accessibilityTrusted: @escaping () -> Bool,
        screenCaptureAuthorized: @escaping () -> Bool,
        requestScreenCapture: @escaping () -> Bool
    ) {
        self.executablePath = executablePath
        self.accessibilityTrusted = accessibilityTrusted
        self.screenCaptureAuthorized = screenCaptureAuthorized
        self.requestScreenCapture = requestScreenCapture
    }

    public func check() throws {
        var missing: [String] = []
        if !accessibilityTrusted() {
            missing.append("Accessibility（アクセシビリティ）対象: \(executablePath)")
        }
        if !screenCaptureAuthorized() && !requestScreenCapture() {
            missing.append("Screen Recording（画面収録）対象: \(executablePath)")
        }
        if !missing.isEmpty {
            throw PlatformError.missingPermissions(missing)
        }
    }

    private static var currentExecutablePath: String {
        Bundle.main.executablePath
            ?? ProcessInfo.processInfo.arguments.first
            ?? "kindle-to-pdf"
    }

    private static var isAccessibilityTrusted: () -> Bool {
        {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
    }
}
