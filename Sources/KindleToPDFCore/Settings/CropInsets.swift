public struct CropInsets: Codable, Equatable {
    public var top: Int
    public var bottom: Int
    public var left: Int
    public var right: Int

    public static let zero = CropInsets(top: 0, bottom: 0, left: 0, right: 0)

    public init(top: Int, bottom: Int, left: Int, right: Int) {
        self.top = max(0, top)
        self.bottom = max(0, bottom)
        self.left = max(0, left)
        self.right = max(0, right)
    }

    public var isZero: Bool { self == .zero }
}
