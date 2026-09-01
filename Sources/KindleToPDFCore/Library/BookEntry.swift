import Foundation

public enum BookStatus: String, Codable {
    case scanning
    case ready
    case completed
}

public struct BookEntry: Codable, Equatable, Identifiable {
    public let id: UUID
    public var displayName: String
    public var createdAt: Date
    public var updatedAt: Date
    public var status: BookStatus
    public var sessionPath: String
    public var pdfPath: String?
    public var capturedPageCount: Int
    public var requestedPageCount: Int?
    public var cropOverride: CropInsets?

    public init(
        id: UUID,
        displayName: String,
        createdAt: Date,
        updatedAt: Date,
        status: BookStatus,
        sessionPath: String,
        pdfPath: String?,
        capturedPageCount: Int,
        requestedPageCount: Int?,
        cropOverride: CropInsets?
    ) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.sessionPath = sessionPath
        self.pdfPath = pdfPath
        self.capturedPageCount = capturedPageCount
        self.requestedPageCount = requestedPageCount
        self.cropOverride = cropOverride
    }
}
