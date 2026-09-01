import ApplicationServices
import CoreGraphics

public struct PermissionStatus: Equatable {
    public var accessibility: Bool
    public var screenRecording: Bool

    public init(accessibility: Bool, screenRecording: Bool) {
        self.accessibility = accessibility
        self.screenRecording = screenRecording
    }
}

public struct MacOSPermissionChecker: PermissionChecking {
    private let executablePath: String
    private let accessibilityTrusted: () -> Bool
    private let screenCaptureAuthorized: () -> Bool
    private let requestScreenCapture: () -> Bool
    private let statusAccessibilityTrusted: () -> Bool

    public init() {
        self.init(
            executablePath: Self.currentExecutablePath,
            accessibilityTrusted: Self.isAccessibilityTrusted,
            screenCaptureAuthorized: CGPreflightScreenCaptureAccess,
            requestScreenCapture: CGRequestScreenCaptureAccess,
            statusAccessibilityTrusted: Self.isAccessibilityTrustedWithoutPrompt
        )
    }

    init(
        executablePath: String,
        accessibilityTrusted: @escaping () -> Bool,
        screenCaptureAuthorized: @escaping () -> Bool,
        requestScreenCapture: @escaping () -> Bool,
        statusAccessibilityTrusted: (() -> Bool)? = nil
    ) {
        self.executablePath = executablePath
        self.accessibilityTrusted = accessibilityTrusted
        self.screenCaptureAuthorized = screenCaptureAuthorized
        self.requestScreenCapture = requestScreenCapture
        self.statusAccessibilityTrusted = statusAccessibilityTrusted ?? accessibilityTrusted
    }

    public func status() -> PermissionStatus {
        PermissionStatus(
            accessibility: statusAccessibilityTrusted(),
            screenRecording: screenCaptureAuthorized()
        )
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
        { Self.accessibilityTrusted(prompt: true) }
    }

    private static var isAccessibilityTrustedWithoutPrompt: () -> Bool {
        { Self.accessibilityTrusted(prompt: false) }
    }

    private static func accessibilityTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
