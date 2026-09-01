import Foundation

public struct AppSettings: Codable, Equatable {
    public var libraryRootPath: String
    public var defaultNextKey: NextKey
    public var defaultPageCount: Int?
    public var autoCropEnabled: Bool
    public var globalCropInsets: CropInsets

    public static let `default` = AppSettings(
        libraryRootPath: LibraryPaths.defaultRootURL.path,
        defaultNextKey: .right,
        defaultPageCount: nil,
        autoCropEnabled: true,
        globalCropInsets: .zero
    )

    public init(
        libraryRootPath: String,
        defaultNextKey: NextKey,
        defaultPageCount: Int?,
        autoCropEnabled: Bool,
        globalCropInsets: CropInsets
    ) {
        self.libraryRootPath = libraryRootPath
        self.defaultNextKey = defaultNextKey
        self.defaultPageCount = defaultPageCount
        self.autoCropEnabled = autoCropEnabled
        self.globalCropInsets = globalCropInsets
    }
}
