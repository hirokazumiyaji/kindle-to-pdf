import CoreGraphics
import CryptoKit
import Foundation

public final class CaptureCoordinator {
    private let windowLocator: WindowLocating
    private let permissionChecker: PermissionChecking
    private let pageTurner: PageTurning
    private let windowCapture: WindowCapturing
    private let imageCodec: PNGImageCodec
    private let imageChangeDetector: ImageChangeDetector
    private let pdfWriter: PDFWriting
    private let sleeper: Sleeper
    private let stabilityAttempts = 20
    private let stabilityInterval: TimeInterval = 0.25

    public init(
        windowLocator: WindowLocating,
        permissionChecker: PermissionChecking,
        pageTurner: PageTurning,
        windowCapture: WindowCapturing,
        imageCodec: PNGImageCodec,
        imageChangeDetector: ImageChangeDetector,
        pdfWriter: PDFWriting,
        sleeper: Sleeper
    ) {
        self.windowLocator = windowLocator
        self.permissionChecker = permissionChecker
        self.pageTurner = pageTurner
        self.windowCapture = windowCapture
        self.imageCodec = imageCodec
        self.imageChangeDetector = imageChangeDetector
        self.pdfWriter = pdfWriter
        self.sleeper = sleeper
    }

    public func run(
        options: CaptureOptions,
        stopRequested: @escaping () -> Bool
    ) throws {
        let sessionURL = options.sessionURL ?? options.outputURL
            .deletingPathExtension()
            .appendingPathExtension("kindle-session")
        let store = SessionStore(rootURL: sessionURL)
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: options.outputURL.path), !options.overwrite {
            throw CaptureError.outputAlreadyExists(options.outputURL)
        }
        if fileManager.fileExists(atPath: sessionURL.path), !options.resume {
            throw CaptureError.sessionAlreadyExists(sessionURL)
        }

        try permissionChecker.check()
        let window = try windowLocator.locate(title: options.windowTitle)

        var state: SessionState
        var previousImage: CGImage
        if options.resume {
            state = try store.load()
            try validateResume(state: state, options: options, store: store)
            guard let pageData = try? Data(contentsOf: store.pageURL(index: state.capturedPageCount)) else {
                throw CaptureError.invalidResume("最後のページ画像がありません。")
            }
            previousImage = try imageCodec.decode(pageData)
        } else {
            previousImage = try windowCapture.capture(window: window)
            let pageData = try imageCodec.encode(previousImage)
            try store.savePage(pageData, index: 1)
            state = SessionState(
                schemaVersion: 1,
                outputPath: options.outputURL.path,
                requestedPageCount: options.pageCount,
                capturedPageCount: 1,
                windowTitle: window.title,
                windowID: window.windowID,
                processID: window.processID,
                lastImageHash: hash(pageData),
                status: .capturing
            )
            try store.save(state)
        }

        while state.capturedPageCount < options.pageCount {
            if stopRequested() {
                throw CaptureError.stopRequested
            }
            try pageTurner.turn(window: window, key: options.nextKey)
            let nextImage = try waitForPage(
                after: previousImage,
                window: window,
                stopRequested: stopRequested,
                pageNumber: state.capturedPageCount + 1
            )
            let pageData = try imageCodec.encode(nextImage)
            let nextPage = state.capturedPageCount + 1
            try store.savePage(pageData, index: nextPage)
            state.capturedPageCount = nextPage
            state.lastImageHash = hash(pageData)
            try store.save(state)
            previousImage = nextImage
        }

        try pdfWriter.write(
            imageURLs: store.pageURLs(count: state.capturedPageCount),
            to: options.outputURL
        )
        state.status = .completed
        try store.save(state)
    }

    private func waitForPage(
        after previousImage: CGImage,
        window: KindleWindow,
        stopRequested: () -> Bool,
        pageNumber: Int
    ) throws -> CGImage {
        var samples: [CGImage] = []
        for _ in 0..<stabilityAttempts {
            if stopRequested() {
                throw CaptureError.stopRequested
            }
            try sleeper.sleep(for: stabilityInterval)
            let image = try windowCapture.capture(window: window)
            guard try imageChangeDetector.hasChanged(previousImage, image) else {
                samples.removeAll(keepingCapacity: true)
                continue
            }

            if let last = samples.last, try imageChangeDetector.hasChanged(last, image) {
                samples = [image]
            } else {
                samples.append(image)
            }
            if try imageChangeDetector.isStable(samples) {
                return image
            }
        }
        throw CaptureError.pageDidNotChange(pageNumber)
    }

    private func validateResume(
        state: SessionState,
        options: CaptureOptions,
        store: SessionStore
    ) throws {
        guard state.schemaVersion == 1 else {
            throw CaptureError.invalidResume("未対応のセッション形式です。")
        }
        guard state.outputPath == options.outputURL.path else {
            throw CaptureError.invalidResume("出力先が一致しません。")
        }
        guard state.requestedPageCount == options.pageCount else {
            throw CaptureError.invalidResume("取得ページ数が一致しません。")
        }
        guard state.status == .capturing else {
            throw CaptureError.invalidResume("セッションは既に完了しています。")
        }
        guard state.capturedPageCount > 0,
              state.capturedPageCount <= state.requestedPageCount else {
            throw CaptureError.invalidResume("保存済みページ数が不正です。")
        }
        for url in store.pageURLs(count: state.capturedPageCount) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw CaptureError.invalidResume("ページ画像が欠落しています: \(url.path)")
            }
        }
    }

    private func hash(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
