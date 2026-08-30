import CoreGraphics

public protocol WindowLocating {
    func locate(title: String?) throws -> KindleWindow
}

public protocol PageTurning {
    func turn(window: KindleWindow, key: NextKey) throws
}

public protocol ApplicationActivating {
    func activate(processID: Int32) throws
}

public protocol WindowCapturing {
    func capture(window: KindleWindow) throws -> CGImage
}

public protocol PermissionChecking {
    func check() throws
}
