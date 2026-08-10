import ApplicationServices
import CoreGraphics

public struct MacOSPermissionChecker: PermissionChecking {
    public init() {}

    public func check() throws {
        var missing: [String] = []
        if !AXIsProcessTrusted() {
            missing.append("Accessibility（システム設定 > プライバシーとセキュリティ > アクセシビリティ）")
        }
        if !CGPreflightScreenCaptureAccess() {
            missing.append("Screen Recording（システム設定 > プライバシーとセキュリティ > 画面収録）")
        }
        if !missing.isEmpty {
            throw PlatformError.missingPermissions(missing)
        }
    }
}
